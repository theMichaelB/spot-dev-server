terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "dvp-devbox"
    key            = "bootstrap-sync/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "dvp-devbox-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
