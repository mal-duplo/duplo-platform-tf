# Resolve tenant and generate a password
data "duplocloud_tenant" "this" {
  name = var.tenant_name
}

locals {
  # duplocloud_tenant data source exposes `id` (tenant GUID)
  tenant_id = data.duplocloud_tenant.this.id
}

resource "random_password" "db_master" {
  length  = 24
  special = true
}

# RDS instance inside tenant-a VPC (Duplo-managed)
resource "duplocloud_rds_instance" "this" {
  tenant_id = local.tenant_id
  name      = "${var.tenant_name}-app-db"

  # Duplo schema:
  # - size: allocated storage in GiB
  # - engine: numeric enum (e.g. 1 = Postgres)
  size           = var.db_allocated_storage
  engine         = 1                      # 1 = PostgreSQL in Duplo’s enum
  engine_version = var.db_engine_version  # e.g. "16.3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result

  multi_az = false

  # At-rest encryption with tenant KMS key
  # Duplo infers encryption from kms_key_id
  kms_key_id = var.tenant_kms_key_arn
}

# Secrets Manager secret encrypted with tenant KMS
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.tenant_name}/rds/appdb"
  description = "RDS app DB credentials for ${var.tenant_name}"
  kms_key_id  = var.tenant_kms_key_arn
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # NOTE: no host/port here (Duplo resource does not expose address/port attributes)
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    dbname   = var.db_name
  })
}