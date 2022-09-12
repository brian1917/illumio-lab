# Lab workloads
resource "aws_security_group" "lab_workload" {
  name   = "lab_workload"
  description = "default rules for lab workloads"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Email = "brian.pitta@illumio.com"
  }

  // Allow allow inbound from within the vpc
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.vpc_cidr_block]
  }

  // Allow allow inbound from the admin ranges
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
}

# PCE workloads
resource "aws_security_group" "pce" {
  name        = "pce"
  description = "communication for pce server"
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Email = "brian.pitta@illumio.com"
  }

  // Allow any inbound on PCE front end https port
  ingress {
    from_port   = 8443
    to_port     = 8444
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Open
resource "aws_security_group" "open" {
  name        = "open"
  description = "open security groups"
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Email = "brian.pitta@illumio.com"
  }

  // Allow allow inbound from everywhere
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}