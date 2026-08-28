# See scenarios/01-s3-exfil/terraform/variables.tf for what a variable
# block is and how Terraform resolves values (CLI -var > terraform.tfvars
# > this file's default). This scenario needs far fewer variables than
# Scenario 1 — there's no networking layer here, just IAM.

variable "aws_region" {
  description = "AWS region to deploy the scenario into"
  type        = string
  default     = "us-east-1"
}

variable "scenario_name" {
  description = "Short name used in resource naming"
  type        = string
  default     = "iam-privesc"
}

variable "ttl_minutes" {
  description = "Intended lifetime of this scenario before teardown (tag/metadata only — same as Scenario 1, no auto-teardown mechanism yet)"
  type        = number
  default     = 60
}
