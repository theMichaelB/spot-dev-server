terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "dvp-devbox"
    key            = "lambda-control/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "dvp-devbox-lock"
  }
}

provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "spot-dev-server"
    }
  }
}
