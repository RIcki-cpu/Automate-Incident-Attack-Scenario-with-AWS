# --- App server -------------------------------------------------------
# This instance and its IAM role are deliberately NOT the vulnerability —
# the role below is scoped to just this scenario's bucket (GetObject/
# PutObject/ListBucket on the data bucket only, nothing account-wide).
# The bucket policy in s3.tf is the actual misconfiguration. This
# instance exists to make the scenario feel like a real app environment
# rather than just a bare S3 bucket sitting in the void.

# Rather than hardcoding an AMI ID (which is region-specific and goes
# stale over time), this looks up the newest matching Amazon Linux 2023
# image at apply time. most_recent + the two filters together mean
# "latest AL2023, 64-bit x86, HVM virtualization."
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# An IAM role is an identity that AWS resources (rather than people) can
# assume. This one only trusts the EC2 service to assume it
# (assume_role_policy below) — nothing else can use this role.
resource "aws_iam_role" "app" {
  name = "${var.scenario_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# The actual permissions attached to the role above. Scoped to exactly
# this bucket's ARN and its objects — NOT "s3:*" and NOT "Resource: *".
# This is the least-privilege contrast the whole scenario is built
# around: the app's own permissions are fine; the bucket's policy (s3.tf)
# is what's wrong.
resource "aws_iam_role_policy" "app_s3_access" {
  name = "${var.scenario_name}-app-s3-access"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.data.arn,
        "${aws_s3_bucket.data.arn}/*",
      ]
    }]
  })
}

# EC2 instances can't use an IAM role directly — an "instance profile" is
# the wrapper that actually attaches a role to an instance. The AWS
# console does this pairing automatically behind the scenes; in
# Terraform it's this separate, explicit resource.
resource "aws_iam_instance_profile" "app" {
  name = "${var.scenario_name}-app-profile"
  role = aws_iam_role.app.name
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  # user_data runs once, as root, the first time the instance boots. This
  # just starts a trivial HTTP server so port 80 (opened in
  # security_group.tf) actually has something behind it — a placeholder,
  # not a real app.
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3
    echo "<h1>${var.scenario_name} scenario app (placeholder)</h1>" > /tmp/index.html
    cd /tmp && nohup python3 -m http.server 80 &
  EOF

  tags = {
    Name = "${var.scenario_name}-app"
  }
}
