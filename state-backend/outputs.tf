output "state_bucket" {
  description = "Name of the S3 state bucket. scripts/remote-state.sh reads this to wire scenarios up to it."
  value       = aws_s3_bucket.state.id
}
