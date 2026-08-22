# This file pins WHICH Terraform version and WHICH provider version this
# scenario was built against. Terraform providers (like "aws" below) are
# plugins that translate .tf resource blocks into actual API calls — the
# AWS provider is what knows how to turn `resource "aws_vpc"` into a real
# CreateVpc call. Pinning versions here means `terraform init` always
# downloads a predictable version instead of "whatever is newest today."

terraform {
  required_version = ">= 1.9" # the Terraform CLI version itself

  required_providers {
    aws = {
      source  = "hashicorp/aws" # where to fetch the provider plugin from
      version = "~> 5.0"        # "~> 5.0" means "any 5.x, but not 6.0"
    }
  }
}

# The provider block configures how Terraform talks to AWS: which region,
# and (via default_tags) what tags to stamp onto every resource it creates.
# default_tags is the project's cost/cleanup safety net — see CLAUDE.md's
# "Cost/safety convention" section. It reads AWS credentials from
# ~/.aws/credentials automatically (set up via `aws configure`); there is
# no access key/secret in this file or anywhere in this repo.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "aws-attack-defense-scenario-kit"
      Scenario   = "01-s3-exfil"
      ManagedBy  = "terraform"
      TTLMinutes = var.ttl_minutes
    }
  }
}

# A "data" block reads existing information from AWS instead of creating
# something new. This one just looks up which AWS account we're deployed
# into (its 12-digit account ID), which other files use to make S3 bucket
# names globally unique (S3 bucket names must be unique across ALL AWS
# accounts, not just yours).
data "aws_caller_identity" "current" {}
