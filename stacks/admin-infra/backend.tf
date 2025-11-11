terraform { 
    backend "s3" {} 
}

# terraform {
#   backend "s3" {
#     bucket               = "malduplo-tfstate-tes10"
#     key                  = "admin-infra/terraform.tfstate"
#     region               = "us-east-2"
#     dynamodb_table       = "malduplo-tfstate-938690564755-lock"
#     encrypt              = true
#     workspace_key_prefix = "env"
#     profile              = "duplo-admin"
#   }
# }
