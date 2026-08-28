# This file pins WHICH Terraform version and WHICH provider version this
# scenario was built against — see scenarios/01-s3-exfil/terraform/versions.tf
# for the full explanation of what a provider/required_providers block is;
# this one follows the identical pattern.

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "aws-attack-defense-scenario-kit"
      Scenario   = "02-iam-privesc"
      ManagedBy  = "terraform"
      TTLMinutes = var.ttl_minutes
    }
  }
}

data "aws_caller_identity" "current" {}
