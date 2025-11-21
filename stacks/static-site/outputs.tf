output "static_site_bucket" {
  value = aws_s3_bucket.static_site.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.static.domain_name
}

output "static_site_url" {
  value = "https://${local.domain_name}"
}