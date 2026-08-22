# A security group is a virtual firewall attached to the EC2 instance
# itself (not the subnet — that's a different, unused-here AWS concept
# called a "network ACL"). Rules are allow-only and stateful: an allowed
# inbound request's response traffic is automatically allowed back out —
# you don't need a matching egress rule just to let replies through.
#
# NOTE: there is deliberately NO SSH (port 22) rule here. This scenario's
# attack is anonymous S3 access run from your own machine — it never
# touches this instance — so an SSH rule would be attack surface with no
# purpose (and this scenario creates no EC2 key pair, so it wouldn't even
# work). Port 22 comes back in Week 2, when Ansible needs SSH to
# configure instances.

resource "aws_security_group" "app" {
  name        = "${var.scenario_name}-app-sg"
  description = "Scenario app server: HTTP only (simulated public web app); no SSH by design"
  vpc_id      = aws_vpc.this.id

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
