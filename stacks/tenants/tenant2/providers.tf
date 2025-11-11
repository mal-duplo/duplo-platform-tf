terraform {
  required_version = ">= 1.5.0"
  required_providers {
    duplocloud = { source = "duplocloud/duplocloud", version = "~> 0.11.27" }
  }
}
provider "duplocloud" {}