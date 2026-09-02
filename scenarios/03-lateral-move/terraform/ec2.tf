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

# Uploads YOUR existing public key as an EC2 key pair so you (and Ansible)
# can log in. pathexpand() turns a leading ~ into your home directory;
# file() reads the key's contents. The private half never leaves your
# machine. This key authorizes the operator onto BOTH hosts — Ansible uses
# it to configure B by hopping through A (a bastion/ProxyJump), since B has
# no public IP. The attacker's A->B pivot uses a DIFFERENT, deliberately
# leaked key that Ansible stages on A (see the ansible/ playbook).
resource "aws_key_pair" "operator" {
  key_name   = "${var.scenario_name}-operator"
  public_key = file(pathexpand(var.public_key_path))
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
# IP: only reachable from inside the VPC. It holds the decoy "prize"
# (staged by Ansible) that proves the lateral movement succeeded.
resource "aws_instance" "internal" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.internal.id]
  key_name               = aws_key_pair.operator.key_name

  tags = {
    Name = "${var.scenario_name}-internal"
  }
}
