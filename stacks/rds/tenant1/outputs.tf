output "endpoint" {
  description = "RDS endpoint (hostname:port)"
  value       = duplocloud_rds_instance.this.endpoint
}

output "host" {
  description = "RDS hostname"
  value       = duplocloud_rds_instance.this.host
}

output "port" {
  description = "RDS port"
  value       = duplocloud_rds_instance.this.port
}