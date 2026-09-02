# The security groups are where this scenario's vulnerability lives.
#
# Intended design (what someone THOUGHT they built):
#   - web host (A): reachable by the operator on SSH; talks to the internal
#     host only on an application port (8080).
#   - internal host (B): a data/service tier that should ONLY accept that
#     app-port traffic from the web tier — never SSH. The web tier has no
#     business opening administrative sessions to the data tier.
#
# The misconfiguration (what was ACTUALLY built): B's security group also
# allows SSH (22) from the web tier's security group. That single extra
# rule is the lateral-movement gap — it turns "A can talk to B's app port"
# into "A can get an interactive shell on B."

# --- Web host SG (instance A) ---------------------------------------------
resource "aws_security_group" "web" {
  name        = "${var.scenario_name}-web-sg"
  description = "Public web host: SSH from the operator only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH from operator (the foothold, not the vulnerability)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.scenario_name}-web-sg"
  }
}

# --- Internal host SG (instance B) ----------------------------------------
resource "aws_security_group" "internal" {
  name        = "${var.scenario_name}-internal-sg"
  description = "Internal host: intended app-port-only from web, but misconfigured to also allow SSH"
  vpc_id      = aws_vpc.this.id

  # LEGITIMATE rule: the web tier is supposed to reach B only here, on the
  # application port. This one is fine.
  ingress {
    description     = "App port from web tier (intended path)"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # THE VULNERABILITY: SSH from the web tier's SG. This should not exist —
  # the web tier should never be able to open a shell on the internal
  # host. It's what lets an attacker who lands on A pivot to B.
  ingress {
    description     = "MISCONFIGURATION: SSH from web tier (the lateral-movement gap)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "All outbound (private subnet has no internet route anyway)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.scenario_name}-internal-sg"
  }
}
