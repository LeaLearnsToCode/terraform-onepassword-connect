terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.54.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.0.0-rc2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
}

locals {
  aws_region   = "us-west-2"
  vpc_cidr     = "10.0.0.0/23"
  public_cidr  = "10.0.0.0/24"
  private_cidr = "10.0.1.0/24"
}

#data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

provider "aws" {
  region = local.aws_region

  default_tags {
    tags = {
      app-env      = var.app_env
      source-repo  = "https://github.com/LeaLearnsToCode/terraform-onepassword-connect"
      created-with = "automation"
    }
  }
}

provider "cloudflare" {}
provider "random" {}
