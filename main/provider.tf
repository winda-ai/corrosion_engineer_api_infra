// AWS provider configuration. Versions and required providers are declared in versions.tf
provider "aws" {
  region = var.aws_region
} 