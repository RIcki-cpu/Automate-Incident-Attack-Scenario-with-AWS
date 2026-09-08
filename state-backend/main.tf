# --- Terraform remote-state backend: bootstrap ----------------------------
# This tiny config creates ONE S3 bucket to hold Terraform state for the
# scenarios. It solves the classic chicken-and-egg problem: a `backend "s3"`
# block can't point at a bucket that doesn't exist yet, and you can't create
# that bucket with the same config that uses it as its backend. So this
# bootstrap deliberately uses LOCAL state (no backend block) and its only
# job is to create the bucket. Run it ONCE; then any scenario can opt in to
# remote state with scripts/remote-state.sh (see docs/remote-state.md).
#
# Using remote state at all is OPTIONAL — every scenario works fine with
# local state out of the box. This is here to demonstrate the best-practice
# setup (versioned + encrypted + private state, with S3-native locking so no
# DynamoDB table is needed) for anyone who wants it.

terraform {
  # S3-native state locking (use_lockfile, used by the scenarios' backend
  # config) needs Terraform >= 1.10 — which is also why no DynamoDB lock
  # table is required any more.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # No backend block: this bootstrap uses local state on purpose.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "aws-attack-defense-scenario-kit"
      ManagedBy = "terraform"
      Purpose   = "tf-state-backend"
    }
  }
}

data "aws_caller_identity" "current" {}

# The state bucket. Named with the account ID so it's globally unique and
# matches the `tfstate-*` prefix the deploy policy allows.
resource "aws_s3_bucket" "state" {
  bucket = "tfstate-${data.aws_caller_identity.current.account_id}"

  # Best practice is to NOT force_destroy a state bucket (you don't want to
  # casually wipe every scenario's state history). Left as a variable so a
  # lab user can flip it to tear the bucket down easily; default false.
  force_destroy = var.force_destroy

  tags = {
    Name = "tfstate-${data.aws_caller_identity.current.account_id}"
  }
}

# Versioning: keeps a history of every state file, so a bad apply/destroy
# can be rolled back. Non-negotiable for a real state bucket.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (state can contain sensitive values).
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State must never be public — block every avenue.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
