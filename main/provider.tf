// Terraform and provider versions
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

// AWS provider configuration
provider "aws" {
  region = var.region

  assume_role {
    role_arn = var.assume_role_arn
  }
} 