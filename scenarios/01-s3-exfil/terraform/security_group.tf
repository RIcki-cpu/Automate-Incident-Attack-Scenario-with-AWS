# A security group is a virtual firewall attached to the EC2 instance
# itself (not the subnet — that's a different, unused-here AWS concept
# called a "network ACL"). Rules are allow-only and stateful: an allowed
# inbound request's response traffic is automatically allowed back out —
# you don't need a matching egress rule just to let replies through.

resource "aws_security_group" "app" {
  name        = "${var.scenario_name}-app-sg"
  description = "Scenario app server: SSH from operator IP + HTTP from anywhere (simulated public web app)"
  vpc_id      = aws_vpc.this.id

  # Locked to var.allowed_ssh_cidr (your IP/32) — this is deliberately
  # NOT part of this scenario's vulnerability. If you ever see this as
  # 0.0.0.0/0, that's a mistake to fix, not a scenario feature.
  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Open to the world on purpose — this simulates a normal public web
  # app and exists for realism. It is NOT the misconfiguration this
  # scenario teaches (that's the S3 bucket policy in s3.tf).
  ingress {
    description = "HTTP (simulated app)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # protocol = "-1" means "all protocols," and paired with from_port/
  # to_port = 0 that means "all ports" — this instance can initiate any
  # outbound connection. Normal default for a lab; a production security
  # group would scope this down.
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.scenario_name}-app-sg"
  }
}
