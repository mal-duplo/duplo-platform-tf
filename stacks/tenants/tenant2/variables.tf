variable "name" {
  description = "The name of the tenant"
  type        = string
  nullable    = true
  default     = null
}

variable "infra_name" {
  description = "The name of the infrastructure (plan) to use"
  type        = string
  nullable    = true
  default     = null
}

variable "parent" {
  description = "Optional parent tenant. Mutually exclusive with infra_name."
  type        = string
  nullable    = true
  default     = null
#   validation {
#     condition     = !(var.parent != null && var.infra_name != null)
#     error_message = "parent and infra_name are mutually exclusive. Using parent will infer the infrastructure."
#   }
}

variable "security_rules" {
  description = <<EOT
A list of security group rules to apply to the tenant.
If neither source_tenant nor source_address is given, the rule means 'parent -> this tenant' and therefore parent must be set.
EOT
  type = set(object({
    description    = optional(string, null)
    protocol       = optional(string, "tcp")
    from_port      = optional(number, null)
    source_tenant  = optional(string, null)
    source_address = optional(string, null)
    to_port        = number
  }))
  default = []
#   validation {
#     condition = !(
#       var.parent == null && anytrue([
#         for rule in var.security_rules : (
#           rule.source_tenant == null &&
#           rule.source_address == null
#         )
#       ])
#     )
#     error_message = "Parent must be set if any security_rules omit source_tenant and source_address."
#   }
}

variable "grants" {
  description = <<EOT
Cross-tenant grants. If grantee is omitted, it implies parent -> this tenant (requires parent).
Allowed areas: s3, dynamodb, kms.
EOT
  type = set(object({
    area    = string
    grantee = optional(string, null)
  }))
  default = []
  validation {
    condition = !anytrue([for g in var.grants : !contains(["s3","dynamodb","kms"], g.area)])
    error_message = "grant.area must be one of: s3, dynamodb, kms."
  }
#   validation {
#     condition = !(
#       var.parent == null && anytrue([for g in var.grants : g.grantee == null])
#     )
#     error_message = "Parent must be set if any grant omits grantee (implies parent -> this tenant)."
#   }
}

variable "settings" {
  description = "Tenant settings map (e.g., delete_protection)."
  type        = map(string)
  default     = null
  nullable    = true
}

variable "configurations" {
  description = "Optional per-tenant configuration objects."
  type = list(object({
    enabled     = optional(bool, true)
    class       = optional(string, "configmap")
    external    = optional(bool, false)
    name        = optional(string, null)
    description = optional(string, null)
    type        = optional(string, "environment") # environment or file
    data        = optional(map(string), null)
    value       = optional(string, null)
    managed     = optional(bool, true)
    csi         = optional(bool, false)
    mountPath   = optional(string, null)
  }))
  default = []
}