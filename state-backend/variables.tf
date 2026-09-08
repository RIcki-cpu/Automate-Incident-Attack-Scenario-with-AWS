variable "aws_region" {
  description = "Region for the state bucket (use the same region you run the scenarios in)"
  type        = string
  default     = "us-east-1"
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete the state bucket even with versions in it. Best practice is false; set true only in a throwaway lab when you want easy teardown."
  type        = bool
  default     = false
}
