# Create VPC, internet gateway, and default route.
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name  = "${var.aws_vpc_name}-vpc"
    Email = var.email_tag
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name  = "${var.aws_vpc_name}-gateway"
    Email = var.email_tag
  }
}
resource "aws_route" "default_route" {
  route_table_id         = aws_vpc.vpc.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Create a subnet for each entry povided
resource "aws_subnet" "subnet" {
  for_each   = var.subnets
  vpc_id     = aws_vpc.vpc.id
  cidr_block = each.value
  tags = {
    Name  = "${var.aws_vpc_name}-${each.key}"
    Email = var.email_tag
  }
}

# Create the key pair for workloads and PCE
resource "aws_key_pair" "auth" {
  key_name   = "${var.aws_vpc_name}-key"
  public_key = file(var.public_sshkey)
  tags = {
    Name  = "${var.aws_vpc_name}-keypair"
    Email = var.email_tag
  }
}

# Create the route 53 zone for PCE and workload DNS
data "aws_route53_zone" "zone" {
  name         = var.domain
  private_zone = false
}

# Find all of the AMIs
data "aws_ami" "amis" {
  for_each    = var.amis
  owners      = [each.value["owner"]]
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = [each.value["ami"]]
  }
}

# Build lab rules
resource "aws_security_group" "lab-rules" {
  name   = "lab-rules"
  vpc_id = aws_vpc.vpc.id

  // Allow allow inbound from within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.vpc_cidr_block]
  }

  // Allow allow inbound from the admin CIDR block
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = var.admin_cidr_list
  }

  // Allow outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.aws_vpc_name}-lab-rules-SG"
    Email = var.email_tag
  }
}
