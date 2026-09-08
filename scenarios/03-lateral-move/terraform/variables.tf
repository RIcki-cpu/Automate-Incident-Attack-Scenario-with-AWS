# Inputs for the lateral-movement scenario. See
# scenarios/01-s3-exfil/terraform/variables.tf for how Terraform resolves
# variable values (CLI -var > terraform.tfvars > default).

variable "aws_region" {
  description = "AWS region to deploy the scenario into"
  type        = string
  default     = "us-east-1"
}

variable "scenario_name" {
  description = "Short name used in resource naming (must stay within the lateral-move-* prefix the deploy policy allows)"
  type        = string
  default     = "lateral-move"
}

variable "ttl_minutes" {
  description = "Intended lifetime before teardown (tag/metadata only)"
  type        = number
  default     = 60
}

variable "instance_type" {
  description = "EC2 instance type for both hosts"
  type        = string
  default     = "t3.micro"
}

# No default on purpose: Terraform will refuse to run until you set this,
# forcing a conscious choice instead of accidentally exposing SSH to the
# whole internet. This is the operator's own IP — how YOU reach the
# public "web" host to start the exercise. It is NOT the vulnerability.
variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the public web host (the operator's foothold). Set to YOUR_IP/32 — find it with: curl -s ifconfig.me"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "Please enter a valid IPv4 address or CIDR block, e.g. 203.0.113.10/32."
  }
}

# The public half of an SSH key pair you already have. Terraform uploads
# it as an EC2 key pair so you (and Ansible) can log into the hosts. The
# matching PRIVATE key never leaves your machine. ~ is expanded for you.
variable "public_key_path" {
  description = "Path to your SSH public key (used for the operator foothold into the web host)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
