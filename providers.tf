terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      managed_by     = "terraform"
      module_created = true
      module_name    = "terraform-aws-pablosspot-ecs"
    }
  }
}
