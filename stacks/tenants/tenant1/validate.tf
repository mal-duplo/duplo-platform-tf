locals {
  rules_need_parent = anytrue([
    for r in var.security_rules :
    (r.source_tenant == null && r.source_address == null)
  ])

  grants_need_parent = anytrue([
    for g in var.grants : g.grantee == null
  ])

  bad_grant_areas = [
    for g in var.grants : g.area
    if !contains(["s3","dynamodb","kms"], g.area)
  ]
}

resource "null_resource" "validate_inputs" {
  lifecycle {
    precondition {
      condition     = !(var.parent != null && var.infra_name != null)
      error_message = "parent and infra_name are mutually exclusive."
    }
    precondition {
      condition     = !(local.rules_need_parent && var.parent == null)
      error_message = "Parent must be set if any security_rules omit source_tenant and source_address."
    }
    precondition {
      condition     = !(local.grants_need_parent && var.parent == null)
      error_message = "Parent must be set if any grant omits grantee (implies parent -> this tenant)."
    }
    precondition {
      condition     = length(local.bad_grant_areas) == 0
      error_message = "grant.area must be one of: s3, dynamodb, kms."
    }
  }
}