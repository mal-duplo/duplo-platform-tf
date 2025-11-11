locals {
  name      = coalesce(var.name, terraform.workspace)

  # Resolve infra name:
  # 1) prefer explicit var.infra_name (from tenant.tfvars)
  # 2) if a parent tenant is specified, inherit its plan_id
  # 3) otherwise default to "default"
  infra_name = coalesce(
    var.infra_name,
    var.parent != null ? local.parent.plan_id : "default"
  )

  # Only needed if you enable `parent`, `grants`, or `security_rules`
  tenant_id = duplocloud_tenant.this.tenant_id
  parent    = var.parent != null ? data.duplocloud_tenant.parent[0] : null

  siblings = [
    for grant in var.grants : grant.grantee
    if grant.grantee != null
  ]
}

data "duplocloud_tenant" "parent" {
  count = var.parent != null ? 1 : 0
  name  = var.parent
}

data "duplocloud_tenant" "siblings" {
  for_each = toset(local.siblings)
  name     = each.value
}
