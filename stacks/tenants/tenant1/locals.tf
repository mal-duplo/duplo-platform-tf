locals {
  name = coalesce(var.name, terraform.workspace)
  # match the module’s logic: allow override via var.infra_name, else use infra state
  infra_name = coalesce(var.infra_name, data.terraform_remote_state.infra.outputs.infra_name)

  # only needed if you enable `parent`, `grants`, or `security_rules`
  tenant_id  = duplocloud_tenant.this.tenant_id
  parent_obj = var.parent != null ? data.duplocloud_tenant.parent[0] : null

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