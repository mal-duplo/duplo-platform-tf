output "port" {
  description = "RDS port"
  value       = duplocloud_rds_instance.this.port
}

output "secret_arn" {
  description = "Secrets Manager ARN containing DB creds"
  value       = aws_secretsmanager_secret.db_credentials.arn
}