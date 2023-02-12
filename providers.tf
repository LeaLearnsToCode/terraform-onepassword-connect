terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.54.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      app_env = var.app_env
      source-repo = "https://github.com/LeaLearnsToCode/terraform-onepassword-connect"
      created-with = "automation"
    }
  }
}
