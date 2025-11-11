output "infra_name" {
  value = duplocloud_infrastructure.this.infra_name
}

output "region" {
  value = var.region
}

output "address_prefix" {
  value = local.address_prefix
}