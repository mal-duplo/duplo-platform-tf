# Tenant lookup
data "duplocloud_tenant" "tenant_a" {
  name = "tenant-a"
}

# S3 bucket (Duplo-managed)
resource "duplocloud_s3_bucket" "static_site" {
  tenant_id           = data.duplocloud_tenant.tenant_a.id
  name                = "static-site"

  allow_public_access = false
  enable_access_logs  = false
  enable_versioning   = true
  managed_policies    = ["ssl"]  # require HTTPS

  default_encryption {
    method = "Sse"
  }
}

# Upload content to S3
resource "aws_s3_object" "index_html" {
  bucket       = duplocloud_s3_bucket.static_site.fullname
  key          = "index.html"
  source       = "${path.module}/site/index.html"
  etag         = filemd5("${path.module}/site/index.html")
  content_type = "text/html"
}

# ACM certificate lookup

data "aws_acm_certificate" "mal_apps" {
  domain      = "*.mal-apps.duplocloud.net"
  statuses    = ["ISSUED"]
  most_recent = true
}

# CloudFront distribution (Duplo-managed)
resource "duplocloud_aws_cloudfront_distribution" "static" {
  tenant_id = data.duplocloud_tenant.tenant_a.id
  comment   = "Static site for ${local.domain_name}"

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [local.domain_name]

  origin {
    domain_name = "${duplocloud_s3_bucket.static_site.fullname}.s3.${local.region}.amazonaws.com"
    origin_id   = "s3-static-site-origin"
  }

  default_cache_behavior {
    target_origin_id       = "s3-static-site-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.mal_apps.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [aws_s3_object.index_html]
}

# Route53 alias -> CloudFront
data "aws_route53_zone" "this" {
  name         = "mal-apps.duplocloud.net."
  private_zone = false
}

resource "aws_route53_record" "static_alias" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = duplocloud_aws_cloudfront_distribution.static.domain_name
    zone_id                = duplocloud_aws_cloudfront_distribution.static.hosted_zone_id
    evaluate_target_health = false
  }
}