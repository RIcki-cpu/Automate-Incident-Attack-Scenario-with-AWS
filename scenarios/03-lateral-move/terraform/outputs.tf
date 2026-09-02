# Values the attack/detect scripts and the Ansible config read via
# `terraform output`. See scenarios/01-s3-exfil/terraform/outputs.tf for
# how `terraform output` works.

output "web_public_ip" {
  description = "Public IP of the web host (instance A) — the operator's foothold"
  value       = aws_instance.web.public_ip
}

output "web_instance_id" {
  value = aws_instance.web.id
}

output "internal_private_ip" {
  description = "Private IP of the internal host (instance B) — the pivot target"
  value       = aws_instance.internal.private_ip
}

output "internal_instance_id" {
  value = aws_instance.internal.id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "flow_log_group" {
  description = "CloudWatch Logs group the VPC Flow Logs are delivered to (detect.sh queries this)"
  value       = aws_cloudwatch_log_group.flow.name
}

output "ssh_to_web_hint" {
  description = "How to reach the foothold host"
  value       = "ssh ec2-user@${aws_instance.web.public_ip}"
}
