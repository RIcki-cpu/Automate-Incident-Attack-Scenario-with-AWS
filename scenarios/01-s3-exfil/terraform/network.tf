# This file builds the minimum networking AWS requires before an EC2
# instance can be reachable from the internet: a VPC (your own private
# slice of AWS network space), a subnet inside it, an internet gateway
# (the VPC's "door" to the public internet), and a route table that tells
# traffic to actually use that door.

# AWS regions are split into multiple physical, isolated data centers
# ("Availability Zones"). This just asks "which AZs are usable right now
# in this region" so the subnet below can pick one instead of hardcoding
# an AZ name that might not exist in every region (e.g. us-east-1 has
# 6 AZs, other regions have fewer).
data "aws_availability_zones" "available" {
  state = "available"
}

# The VPC: an isolated network, sized by its CIDR block. 10.66.0.0/16
# means "10.66.0.0 through 10.66.255.255" (~65k addresses) — an arbitrary
# private-range choice, it doesn't need to match your home/office network.
resource "aws_vpc" "this" {
  cidr_block           = "10.66.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true # lets the EC2 instance get a public DNS name

  tags = {
    Name = "${var.scenario_name}-vpc"
  }
}

# Without an Internet Gateway attached to the VPC, NOTHING inside it can
# reach (or be reached from) the public internet, no matter how the
# security group or subnet is configured.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.scenario_name}-igw"
  }
}

# A subnet is a slice of the VPC's address range tied to one AZ. "public"
# here is just a naming choice reflecting intent — what actually makes it
# public is the route table below. map_public_ip_on_launch means any
# instance launched here automatically gets a public IP; without it the
# EC2 instance in ec2.tf couldn't be reached (or reach out) at all.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.66.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.scenario_name}-public-subnet"
  }
}

# A route table is the VPC's routing rule set: "traffic to THIS
# destination goes THROUGH that gateway/device." The single route below
# reads as "anything not already inside this VPC (0.0.0.0/0) goes out via
# the internet gateway" — this is what actually makes the subnet public;
# without this route, the subnet would stay private even with an IGW
# attached to the VPC.
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

# A route table does nothing until it's associated with a subnet — this
# is that link.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
