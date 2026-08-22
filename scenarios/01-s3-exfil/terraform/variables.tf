# Every `variable` block below is an input this configuration accepts —
# think of them like function parameters for the whole `terraform/`
# directory. Terraform fills them in from (in order of precedence):
# command-line -var flags, a terraform.tfvars file, then the `default`
# shown here if neither is set. This scenario's actual values go in
# terraform.tfvars (copy terraform.tfvars.example to get started — that
# real file is gitignored so your IP/settings never get committed).

variable "aws_region" {
  description = "AWS region to deploy the scenario into"
  type        = string
  default     = "us-east-1"
}

variable "scenario_name" {
  description = "Short name used in resource naming"
  type        = string
  default     = "s3-exfil"
}

variable "ttl_minutes" {
  description = "Intended lifetime of this scenario before teardown (tag/metadata only for now — auto-teardown lands Week 1 Day 5)"
  type        = number
  default     = 60
}

variable "instance_type" {
  description = "EC2 instance type for the scenario app server"
  type        = string
  default     = "t3.micro" # free-tier eligible; fine for a placeholder app
}
