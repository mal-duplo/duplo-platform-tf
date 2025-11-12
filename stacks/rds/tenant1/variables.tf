variable "tenant_name" {
  description = "Duplo tenant name (e.g. tenant-a)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tenant_kms_key_arn" {
  description = "KMS key ARN for this tenant (from Duplo tenant settings)"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Application DB username (what your app will use)"
  type        = string
  default     = "appuser"
}

variable "db_allocated_storage" {
  description = "RDS storage in GiB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}