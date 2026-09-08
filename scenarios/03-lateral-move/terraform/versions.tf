# Same provider/tags pattern as the other scenarios — see
# scenarios/01-s3-exfil/terraform/versions.tf for the full explanation of
# each block.

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Used to generate the pivot key pair at plan time so the internal host
    # can authorize it at boot (via user_data) — no SSH-in needed to
    # configure B. This is a local-only provider (no AWS calls).
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "aws-attack-defense-scenario-kit"
      Scenario   = "03-lateral-move"
      ManagedBy  = "terraform"
      TTLMinutes = var.ttl_minutes
    }
  }
}

data "aws_caller_identity" "current" {}
