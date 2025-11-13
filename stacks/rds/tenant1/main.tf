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

# Duplo-managed RDS instance inside the tenant VPC
resource "duplocloud_rds_instance" "this" {
  tenant_id = local.tenant_id
  name      = "${var.tenant_name}-app-db"

  engine = 1                          # 1 = PostgreSQL
  size   = var.db_instance_class      # ex: "db.t4g.micro"

  allocated_storage = var.db_allocated_storage
  engine_version    = var.db_engine_version

  master_username = var.db_username
  master_password = random_password.db_master.result

  # Encryption with tenant KMS key
  encrypt_storage = true
  kms_key_id      = var.tenant_kms_key_arn

  multi_az = false
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
    host     = duplocloud_rds_instance.this.host
    port     = duplocloud_rds_instance.this.port
    dbname   = var.db_name
    endpoint = duplocloud_rds_instance.this.endpoint
  })
}