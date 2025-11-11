data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket         = "malduplo-tfstate-938690564755"
    key            = "env/${terraform.workspace}/admin-infra/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "malduplo-tfstate-938690564755-lock"
    profile        = "duplo-admin"
  }
}