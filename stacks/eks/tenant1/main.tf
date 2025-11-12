locals {
  asg_ami = var.asg_ami != null ? var.asg_ami : data.aws_ssm_parameter.eks_ami.value
  zones   = ["a", "b", "c", "d", "e", "f", "g", "h"]
  # New zones field accepts ints and null, logic in place to handle either case.
  asg_zones = length(var.az_list) > 0 ? [
    for zone in var.az_list : contains(local.zones, zone) ? index(local.zones, zone) : null
  ] : null
  minion_tags = [
    for k, v in var.minion_tags : {
      key   = k
      value = v
    }
  ]
  metadata = [
    for k, v in var.metadata : {
      key   = k
      value = v
    }
  ]
  gpu_ssm_path = (
    var.gpu_ami_channel == "al2023-nvidia"        ? "amazon-linux-2023/x86_64/nvidia" :
    var.gpu_ami_channel == "al2023-arm64-nvidia"  ? "amazon-linux-2023/arm64/nvidia"  :
                                                    "amazon-linux-2-gpu"
  )
}

# AL2023 EKS-optimized AMI for your control-plane version
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.eks_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

# Resolve metadata for that AMI id (use filter on image-id)
data "aws_ami" "ami" {
  owners = ["amazon"]
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.eks_ami.value]
  }
}

# # discover the ami
# data "aws_ami" "eks" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["${var.base_ami_name}-${var.eks_version}-*"]
#   }

#   filter {
#     name   = "root-device-type"
#     values = ["ebs"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# # AMI data for both queried and manually input
# data "aws_ami" "ami" {
#   most_recent = true

#   filter {
#     name   = "image-id"
#     values = [local.asg_ami]
#   }
# }

resource "duplocloud_aws_launch_template_default_version" "name" {
  tenant_id       = var.tenant_id
  name            = duplocloud_aws_launch_template.nodes.name
  default_version = duplocloud_aws_launch_template.nodes.latest_version
}

# Uses version 1 as base, though all inputs are changed in this resource, thus making the exact version irrelevant.
resource "duplocloud_aws_launch_template" "nodes" {
  tenant_id           = var.tenant_id
  name                = duplocloud_asg_profile.nodes.fullname
  instance_type       = var.capacity
  version             = 1
  version_description = data.aws_ami.ami.description
  ami                 = local.asg_ami
}

resource "duplocloud_asg_profile" "nodes" {
  zones         = local.asg_zones
  friendly_name = var.prefix
  image_id      = local.asg_ami

  tenant_id           = var.tenant_id
  instance_count      = var.instance_count
  min_instance_count  = var.min_instance_count
  max_instance_count  = var.max_instance_count
  capacity            = var.capacity
  is_ebs_optimized    = var.is_ebs_optimized
  encrypt_disk        = var.encrypt_disk
  use_spot_instances  = var.use_spot_instances
  max_spot_price      = var.max_spot_price
  can_scale_from_zero = var.can_scale_from_zero

  # these stay the same for autoscaling eks nodes
  agent_platform      = 7
  is_minion           = true
  allocated_public_ip = false
  cloud               = 0
  # use_launch_template = true
  is_cluster_autoscaled = true

  metadata {
    key   = "OsDiskSize"
    value = tostring(var.os_disk_size)
  }
  dynamic "metadata" {
    for_each = local.metadata
    content {
      key   = metadata.value.key
      value = metadata.value.value
    }
  }
  dynamic "minion_tags" {
    for_each = local.minion_tags
    content {
      key   = minion_tags.value.key
      value = minion_tags.value.value
    }
  }
  lifecycle {
    ignore_changes = [instance_count, image_id, capacity]
  }
  dynamic "taints" {
    for_each = var.taints
    content {
      key    = taints.value.key
      value  = taints.value.value
      effect = taints.value.effect
    }
  }
}

# Refreshes upon changes to asg_ami and capacity, or upon changing associated variables
resource "duplocloud_asg_instance_refresh" "name" {
  count                  = var.use_auto_refresh ? 1 : 0
  tenant_id              = var.tenant_id
  asg_name               = duplocloud_asg_profile.nodes.fullname
  refresh_identifier     = random_integer.identifier[0].result
  instance_warmup        = var.instance_warmup_seconds
  max_healthy_percentage = var.max_healthy_percentage
  min_healthy_percentage = var.min_healthy_percentage
}

resource "random_integer" "identifier" {
  count = var.use_auto_refresh ? 1 : 0
  min   = 10000
  max   = 99999
  keepers = {
    asg_ami  = local.asg_ami
    capacity = var.capacity
  }
}

# --- GPU AMI (EKS optimized w/ NVIDIA) ---
data "aws_ssm_parameter" "eks_gpu_ami" {
  name = "/aws/service/eks/optimized-ami/${var.eks_version}/${local.gpu_ssm_path}/recommended/image_id"
}

data "aws_ami" "gpu_ami" {
  owners = ["amazon"]
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.eks_gpu_ami.value]
  }
}

# --- GPU locals (mirror the existing maps->lists transforms) ---
locals {
  gpu_asg_ami   = var.gpu_asg_ami != null ? var.gpu_asg_ami : data.aws_ssm_parameter.eks_gpu_ami.value
  gpu_asg_zones = length(var.gpu_az_list) > 0 ? [
    for zone in var.gpu_az_list : contains(local.zones, zone) ? index(local.zones, zone) : null
  ] : null

  gpu_minion_tags = [
    for k, v in var.gpu_minion_tags : { key = k, value = v }
  ]
  gpu_metadata = [
    for k, v in var.gpu_metadata : { key = k, value = v }
  ]
}

# --- GPU Launch Template & ASG profile (enabled by flag) ---
resource "duplocloud_aws_launch_template" "gpu" {
  count               = var.gpu_enabled ? 1 : 0
  tenant_id           = var.tenant_id
  name                = duplocloud_asg_profile.gpu[0].fullname
  instance_type       = var.gpu_capacity
  version             = 1
  version_description = data.aws_ami.gpu_ami.description
  ami                 = local.gpu_asg_ami
}

resource "duplocloud_aws_launch_template_default_version" "gpu" {
  count          = var.gpu_enabled ? 1 : 0
  tenant_id       = var.tenant_id
  name            = duplocloud_aws_launch_template.gpu[0].name
  default_version = duplocloud_aws_launch_template.gpu[0].latest_version
}

resource "duplocloud_asg_profile" "gpu" {
  count = var.gpu_enabled ? 1 : 0

  zones         = local.gpu_asg_zones
  friendly_name = "${var.prefix}-gpu"
  image_id      = local.gpu_asg_ami

  tenant_id           = var.tenant_id
  instance_count      = var.gpu_instance_count
  min_instance_count  = var.gpu_min_instance_count
  max_instance_count  = var.gpu_max_instance_count
  capacity            = var.gpu_capacity
  is_ebs_optimized    = var.gpu_is_ebs_optimized
  encrypt_disk        = var.gpu_encrypt_disk
  use_spot_instances  = var.gpu_use_spot_instances
  max_spot_price      = var.gpu_max_spot_price
  can_scale_from_zero = var.gpu_can_scale_from_zero

  # same fixed bits for EKS workers
  agent_platform        = 7
  is_minion             = true
  allocated_public_ip   = false
  cloud                 = 0
  is_cluster_autoscaled = true

  # root disk
  metadata {
    key   = "OsDiskSize"
    value = tostring(var.gpu_os_disk_size)
  }

  # extra kubelet args / labels / taints via metadata
  dynamic "metadata" {
    for_each = local.gpu_metadata
    content {
      key   = metadata.value.key
      value = metadata.value.value
    }
  }

  dynamic "minion_tags" {
    for_each = local.gpu_minion_tags
    content {
      key   = minion_tags.value.key
      value = minion_tags.value.value
    }
  }

  lifecycle {
    ignore_changes = [instance_count, image_id, capacity]
  }

  dynamic "taints" {
    for_each = var.gpu_taints
    content {
      key    = taints.value.key
      value  = taints.value.value
      effect = taints.value.effect
    }
  }
}

resource "duplocloud_asg_instance_refresh" "gpu" {
  count                  = var.gpu_enabled && var.use_auto_refresh ? 1 : 0
  tenant_id              = var.tenant_id
  asg_name               = duplocloud_asg_profile.gpu[0].fullname
  refresh_identifier     = random_integer.gpu_identifier[0].result
  instance_warmup        = var.instance_warmup_seconds
  max_healthy_percentage = var.max_healthy_percentage
  min_healthy_percentage = var.min_healthy_percentage
}

resource "random_integer" "gpu_identifier" {
  count = var.gpu_enabled && var.use_auto_refresh ? 1 : 0
  min   = 10000
  max   = 99999
  keepers = {
    asg_ami  = local.gpu_asg_ami
    capacity = var.gpu_capacity
  }
}