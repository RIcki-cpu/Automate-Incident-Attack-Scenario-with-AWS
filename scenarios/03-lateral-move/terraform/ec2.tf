# The two hosts. Neither the hosts nor their (absent) IAM roles are the
# vulnerability — the security-group gap in security_groups.tf is. The
# instances exist so there's something to pivot between.

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

# Uploads YOUR existing public key as an EC2 key pair so you can log into
# the WEB host (the operator foothold). pathexpand() turns a leading ~ into
# your home directory; file() reads the key's contents. The private half
# never leaves your machine. Only the web host uses this key — the internal
# host trusts ONLY the leaked pivot key below, so the only way onto B is
# the pivot.
resource "aws_key_pair" "operator" {
  key_name   = "${var.scenario_name}-operator"
  public_key = file(pathexpand(var.public_key_path))
}

# The "pivot" key pair, generated here at plan time. Its PRIVATE half is the
# credential Ansible plants on the web host (modelling a key carelessly left
# on a bastion); its PUBLIC half is baked into the internal host's
# authorized_keys at boot via user_data (below). Generating it in Terraform
# — instead of at attack time — is the crucial detail that lets B be
# configured WITHOUT anyone ever SSHing into it, so the ONLY web->internal
# SSH (port 22) flow that ever appears in VPC Flow Logs is the attack
# itself. (If we configured B by SSHing through A, that setup traffic would
# be indistinguishable from the attack in the flow logs — Flow Logs see only
# IPs/ports, not the key or user.)
resource "tls_private_key" "pivot" {
  algorithm = "ED25519"
}

# Instance A — the public "web" host and the attacker's initial foothold.
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.operator.key_name

  tags = {
    Name = "${var.scenario_name}-web"
  }
}

# Instance B — the private "internal" host and the pivot target. No public
# IP: only reachable from inside the VPC. Deliberately NO key_name — it
# trusts ONLY the leaked pivot key (added below via user_data), so the sole
# way onto B is the pivot. Its config (authorize the pivot key + stage the
# decoy prize) happens entirely at boot via user_data, so nothing ever SSHes
# into B to set it up.
resource "aws_instance" "internal" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.internal.id]

  user_data = <<-EOF
    #!/bin/bash
    # Authorize the (soon-to-be-leaked) pivot key for ec2-user.
    mkdir -p /home/ec2-user/.ssh
    echo "${tls_private_key.pivot.public_key_openssh}" >> /home/ec2-user/.ssh/authorized_keys
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/authorized_keys
    # Stage the decoy "prize", readable by ec2-user (the pivot lands as
    # ec2-user) so reading it is pure lateral movement, no privesc on B.
    mkdir -p /opt/app
    printf '%s\n' \
      '# INTERNAL - do not distribute (DECOY DATA - lab only)' \
      'DB_HOST=internal-db.lateral-move.local' \
      'DB_USER=svc_ecommerce' \
      'DB_PASS=not-a-real-password-decoy-1234' > /opt/app/db_credentials.txt
    chown ec2-user:ec2-user /opt/app/db_credentials.txt
    chmod 600 /opt/app/db_credentials.txt
  EOF

  tags = {
    Name = "${var.scenario_name}-internal"
  }
}
