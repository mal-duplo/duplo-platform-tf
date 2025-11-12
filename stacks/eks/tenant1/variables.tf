variable "tenant_id" {
  type = string
}
variable "prefix" {
  default = "apps"
  type    = string
}
variable "eks_version" {
  type    = string
  default = "1.33"
}
variable "az_list" {
  default     = ["a", "b"]
  type        = list(string)
  description = "The letter at the end of the zone"
}
variable "base_ami_name" {
  default = "amazon-eks-node"
  type    = string
}
variable "capacity" {
  default = "t3.medium"
  type    = string
}
variable "instance_count" {
  default = 1
  type    = number
}
variable "min_instance_count" {
  default = 1
  type    = number
}
variable "max_instance_count" {
  default = 3
  type    = number
}
variable "os_disk_size" {
  default = 20
  type    = number
}
variable "is_ebs_optimized" {
  default = false
  type    = bool
}
variable "encrypt_disk" {
  default = false
  type    = bool
}
variable "minion_tags" {
  type        = map(string)
  description = "Tags to apply to the Duplo Minions"
  default     = {}
}
variable "metadata" {
  type        = map(string)
  description = "Metadata to apply to the Duplo Minions"
  default     = {}
}
variable "taints" {
  description = "List of taints to apply on the ASG nodes. Each taint requires a key, value, and effect (NoSchedule, PreferNoSchedule, or NoExecute)."
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}
variable "asg_ami" {
  default     = null
  description = "Set AMI to static value"
  type        = string
}
variable "use_spot_instances" {
  default = false
  type    = bool
}
variable "max_spot_price" {
  default     = null
  description = "Maximum price to pay for a spot instance in dollars per unit hour, such as 0.40"
  type        = string
}
variable "can_scale_from_zero" {
  default = false
  type    = bool
}
# Used on jan_2025 portal release and newer only
variable "min_healthy_percentage" {
  default     = 90
  description = "Minimum percentage of healthy hosts during Instance Refresh"
  type        = number
}
variable "max_healthy_percentage" {
  default     = 100
  description = "Maximum percentage of healthy hosts during Instance Refresh"
  type        = number
}
variable "instance_warmup_seconds" {
  default     = 300
  description = "Time in seconds to wait for Instance after it becomes available"
  type        = number
}
variable "use_auto_refresh" {
  default     = true
  description = "Automatically refresh instances on AMI/Capacity changes to ASG"
  type        = bool
}
variable "gpu_enabled" { 
  type = bool   
  default = false 
}
variable "gpu_capacity" { 
  type = string 
  default = "g5.xlarge" 
}
variable "gpu_instance_count" { 
  type = number 
  default = 1 
}
variable "gpu_min_instance_count" { 
  type = number 
  default = 0 
}
variable "gpu_max_instance_count" { 
  type = number 
  default = 2 
}
variable "gpu_os_disk_size" { 
  type = number 
  default = 80 
}
variable "gpu_is_ebs_optimized" { 
  type = bool   
  default = true 
}
variable "gpu_encrypt_disk" { 
  type = bool   
  default = false 
}
variable "gpu_use_spot_instances" { 
  type = bool   
  default = false 
}
variable "gpu_max_spot_price" { 
  type = string 
  default = null 
}
variable "gpu_can_scale_from_zero" { 
  type = bool  
  default = false 
}
variable "gpu_az_list" {
  type        = list(string)
  description = "Letters of AZs for GPU nodes"
  default     = ["a","b"]
}
variable "gpu_minion_tags" {
  type        = map(string)
  description = "EC2 tags for GPU workers"
  default     = {}
}
variable "gpu_metadata" {
  type        = map(string)
  description = "Extra Duplo metadata for GPU workers (e.g., KubeletExtraArgs)"
  default     = {}
}
variable "gpu_taints" {
  description = "Taints for GPU nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}
variable "gpu_asg_ami" {
  type        = string
  description = "Override GPU AMI (else use EKS GPU SSM param)"
  default     = null
}