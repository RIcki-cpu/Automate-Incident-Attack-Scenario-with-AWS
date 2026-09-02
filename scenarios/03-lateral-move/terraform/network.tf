# Two-tier network: a PUBLIC subnet for the internet-facing "web" host
# (instance A) and a PRIVATE subnet for the "internal" host (instance B,
# think a data/service tier). The whole point of the scenario is that B
# lives in a private subnet with no route to the internet — the only way
# to reach it is from inside the VPC — and yet the attacker still pivots
# to it because of a security-group gap (see security_groups.tf).

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = "10.77.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.scenario_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.scenario_name}-igw"
  }
}

# --- Public subnet: instance A (web host) ---------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.77.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.scenario_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.scenario_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Private subnet: instance B (internal host) ---------------------------
# Same AZ as the public subnet so A can reach B over the VPC's internal
# network. Its route table has NO 0.0.0.0/0 route — B genuinely cannot
# reach (or be reached from) the internet. There is deliberately no NAT
# gateway (it would cost money and B needs no internet: Ansible reaches it
# by hopping through A, and B's config uses only pre-installed tooling).
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.77.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.scenario_name}-private-subnet"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  # No routes beyond the implicit local (10.77.0.0/16) route — internal only.

  tags = {
    Name = "${var.scenario_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
