terraform {
  backend "s3" {
    bucket         = var.tfstate_bucket_name
    key            = var.tfstate_key
    region         = var.tfstate_region
    dynamodb_table = var.tfstate_lock_table
    encrypt        = true
  }

  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.1.1"
    }
  }
}
