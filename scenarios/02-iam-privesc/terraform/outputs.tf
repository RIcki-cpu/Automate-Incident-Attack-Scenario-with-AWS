# See scenarios/01-s3-exfil/terraform/outputs.tf for what `output` values
# are for. Two of these are marked `sensitive = true` — Terraform will
# still show them via `terraform output -raw <name>`, but never prints
# them in `apply`/`plan` output or logs, which is exactly what
# scripts/attack.sh relies on to read the analyst's credentials safely.

output "analyst_access_key_id" {
  value     = aws_iam_access_key.analyst.id
  sensitive = true
}

output "analyst_secret_access_key" {
  value     = aws_iam_access_key.analyst.secret
  sensitive = true
}

output "broad_read_role_arn" {
  value = aws_iam_role.broad_read.arn
}

output "cloudtrail_trail_arn" {
  value = aws_cloudtrail.this.arn
}

output "trail_logs_bucket" {
  value = aws_s3_bucket.trail_logs.id
}
