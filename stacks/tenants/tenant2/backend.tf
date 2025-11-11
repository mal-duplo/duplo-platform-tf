terraform { 
    backend "s3" {} 
}

# terraform {
#   backend "s3" {
#     bucket               = "malduplo-tfstate-938690564755"
#     key                  = "tenant/terraform.tfstate"
#     region               = "us-west-2"
#     dynamodb_table       = "malduplo-tfstate-938690564755-lock"
#     encrypt              = true
#     workspace_key_prefix = "env"
#     profile              = "duplo-admin"
#   }
# }