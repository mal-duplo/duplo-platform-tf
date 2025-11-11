output "tenant_id"   { value = duplocloud_tenant.this.tenant_id }
output "tenant_name" { value = duplocloud_tenant.this.account_name }
output "plan_id"     { value = local.infra_name }
