terraform {
  required_providers {
    duplocloud = {
      source  = "duplocloud/duplocloud"
      version = ">= 0.11.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "duplocloud" {
  duplo_host  = var.duplo_host
  duplo_token = var.duplo_token
}

provider "aws" {
  region = "us-east-1"
}

locals {
  domain_name = "static.mal-apps.duplocloud.net"
  region      = "us-east-1"
}
