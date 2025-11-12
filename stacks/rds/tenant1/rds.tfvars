tenant_name        = "tenant-a"
aws_region         = "us-east-1"

# From the tenant's KMS key in Duplo UI
tenant_kms_key_arn = "arn:aws:kms:us-east-1:359100918503:key/REPLACE_ME_TENANT_KEY"

db_name            = "appdb"
db_username        = "appuser"
db_instance_class  = "db.t4g.micro"
db_allocated_storage = 20
db_engine_version  = "16.3"