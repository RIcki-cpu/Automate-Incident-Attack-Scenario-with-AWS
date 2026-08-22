# `output` values print after `terraform apply` and can be re-read any
# time with `terraform output` (or `terraform output -raw <name>` for a
# single value without surrounding quotes) — useful so you don't have to
# go dig resource IDs/IPs out of the AWS console by hand.

output "app_instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "data_bucket_name" {
  value = aws_s3_bucket.data.id
}

output "data_bucket_public_url_example" {
  description = "The URL an unauthenticated attacker would GET to exfiltrate the decoy file"
  value       = "https://${aws_s3_bucket.data.bucket_regional_domain_name}/${aws_s3_object.decoy_sensitive_file.key}"
}

output "cloudtrail_trail_arn" {
  value = aws_cloudtrail.this.arn
}

output "trail_logs_bucket" {
  value = aws_s3_bucket.trail_logs.id
}
