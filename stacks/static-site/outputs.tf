output "static_bucket_name" {
  description = "Duplo-managed S3 bucket that stores the static site."
  value       = duplocloud_s3_bucket.static_site.fullname
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution DNS name."
  value       = duplocloud_aws_cloudfront_distribution.static.domain_name
}

output "static_site_url" {
  description = "Friendly URL for the static site."
  value       = "https://${local.domain_name}"
}
