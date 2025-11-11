resource "duplocloud_infrastructure" "this" {
  infra_name               = coalesce(var.name, terraform.workspace)
  cloud                    = local.clouds[local.cloud]
  region                   = var.region
  enable_k8_cluster        = var.enable_k8_cluster
  enable_ecs_cluster       = var.enable_ecs_cluster
  is_serverless_kubernetes = local.classdef.has_autopilot
  address_prefix           = local.address_prefix
  azcount                  = var.azcount
  subnet_cidr              = var.subnet_cidr

  lifecycle {
    ignore_changes = [address_prefix, cloud]
  }
}

resource "duplocloud_infrastructure_setting" "this" {
  count      = var.settings != null ? 1 : 0
  infra_name = duplocloud_infrastructure.this.infra_name

  dynamic "setting" {
    for_each = var.settings
    content {
      key   = setting.key
      value = setting.value
    }
  }

  depends_on = [duplocloud_infrastructure.this]
}

resource "duplocloud_infrastructure_subnet" "this" {
  for_each   = var.subnets
  name       = each.key
  infra_name = duplocloud_infrastructure.this.infra_name

  cidr_block = each.value.cidr_block
  zone       = each.value.zone
  type       = each.value.type

  depends_on = [duplocloud_infrastructure.this]
}