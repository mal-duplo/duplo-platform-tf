########################
# Provider & locals
########################

provider "aws" {
  region = "us-east-1"
}

locals {
  domain_name     = "static.mal-apps.duplocloud.net"
  bucket_name     = "mal-static-site-nonprod"
  log_bucket_name = "mal-static-site-logs-nonprod"
}

########################
# Route53 zone
########################

data "aws_route53_zone" "this" {
  name         = "mal-apps.duplocloud.net."
  private_zone = false
}

########################
# S3 buckets
########################

resource "aws_s3_bucket" "static_site" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_ownership_controls" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "logs" {
  bucket = local.log_bucket_name
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

########################
# CloudFront OAC
########################

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "static-site-oac"
  description                       = "OAC for static site S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

########################
# ACM certificate (existing wildcard)
########################

data "aws_acm_certificate" "this" {
  domain      = "*.mal-apps.duplocloud.net"
  statuses    = ["ISSUED"]
  most_recent = true
}

########################
# CloudFront distribution
########################

resource "aws_cloudfront_distribution" "static" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Static site for ${local.domain_name}"
  default_root_object = "index.html"

  aliases = [local.domain_name]

  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id                = "s3-static-site-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-static-site-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.this.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  #   logging_config {
  #     bucket          = aws_s3_bucket.logs.bucket_regional_domain_name
  #     prefix          = "cloudfront/"
  #     include_cookies = false
  #   }
}

########################
# S3 bucket policy to allow CloudFront
########################

resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.static_site.arn,
          "${aws_s3_bucket.static_site.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.static.arn
          }
        }
      }
    ]
  })
}

########################
# Route53 alias record
########################

resource "aws_route53_record" "static_alias" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static.domain_name
    zone_id                = aws_cloudfront_distribution.static.hosted_zone_id
    evaluate_target_health = false
  }
}