# Resolve tenant and generate a password
data "duplocloud_tenant" "this" {
  name = var.tenant_name
}

locals {
  tenant_id = data.duplocloud_tenant.this.tenant_id
}

resource "random_password" "db_master" {
  length  = 24
  special = true
}

# RDS instance inside tenant-a VPC
resource "duplocloud_rds_instance" "this" {
  tenant_id = local.tenant_id
  name      = "${var.tenant_name}-app-db"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  storage_type   = "gp3"

  db_name     = var.db_name
  db_username = var.db_username
  db_password = random_password.db_master.result

  # At-rest encryption with tenant KMS key
  storage_encrypted = true
  kms_key_id        = var.tenant_kms_key_arn

  allocated_storage       = var.db_allocated_storage
  backup_retention_period = 1

  publicly_accessible = false
  multi_az            = false
  deletion_protection = false
}

# Secrets Manager secret encrypted with tenant KMS
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.tenant_name}/rds/appdb"
  description = "RDS app DB credentials for ${var.tenant_name}"
  kms_key_id  = var.tenant_kms_key_arn
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    host     = duplocloud_rds_instance.this.address
    port     = duplocloud_rds_instance.this.port
    dbname   = var.db_name
  })
}