terraform {
  backend "s3" {
    bucket         = "ardent-aigs-dev-tfstate-bucket"
    key            = "aws/dev/apps/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ardent-aigs-dev-tfstate-locks"
    encrypt        = true
  }

  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
      version = "5.1.1"
    }
    
    minio = {
      source  = "aminueza/minio"
      version = "3.3.0"
    }
  }
}
