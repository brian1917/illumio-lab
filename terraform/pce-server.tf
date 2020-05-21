# Build PCE using the same CentOS image from the Linux workloads
# If the pce.cluster_type is snc, we build 1 server. If it's "mnc" we build 4 servers. If it's anything else, we don't build a server

resource "aws_instance" "pce" {
  count                       = lower(var.pce["cluster_type"]) == "snc" ? 1 : lower(var.pce["cluster_type"]) == "mnc" ? 4 : 0
  ami                         = data.aws_ami.amis[var.pce["ami"]].id
  instance_type               = var.pce["type"]
  vpc_security_group_ids      = [aws_security_group.pce-rules.id]
  subnet_id                   = aws_subnet.subnet[var.pce["subnet"]].id
  associate_public_ip_address = true
  key_name                    = "${var.aws_vpc_name}-key"
  root_block_device {
    delete_on_termination = true
    volume_size           = var.pce["volume_size_gb"]
  }
  tags = {
    Name  = "${var.aws_vpc_name}-pce"
    Email = var.email_tag
  }
}

# PCE DNS

// Set MNC base host names
variable "base_names" {
  type    = list
  default = ["snc-", "core0-", "core1-", "data0-", "data1-"]
}

// Create a private DNS record for each PCE node
resource "aws_route53_record" "pce-private-dns" {
  count   = var.pce["cluster_type"] == "mnc" ? 4 : 1
  zone_id = data.aws_route53_zone.segmentationpov.zone_id
  name    = "${var.base_names[lower(var.pce["cluster_type"]) == "mnc" ? count.index + 1 : 0]}${var.pce["org_name"]}.poc.${data.aws_route53_zone.segmentationpov.name}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.pce[count.index].private_ip]
}

// Create a public DNS record for the pce-cluster
resource "aws_route53_record" "pce-public-dns" {
  zone_id = data.aws_route53_zone.segmentationpov.zone_id
  name    = "${var.pce["org_name"]}.poc.${data.aws_route53_zone.segmentationpov.name}"
  type    = "A"
  ttl     = "30"
  records = lower(var.pce["cluster_type"]) == "mnc" ? [aws_instance.pce[0].public_ip, aws_instance.pce[1].public_ip] : [aws_instance.pce[0].public_ip]
}


# PCE Security Groups
resource "aws_security_group" "pce-rules" {
  name        = "pce-rules"
  description = "Communication for PCE server."
  vpc_id      = aws_vpc.vpc.id

  // Allow allow inbound from within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.vpc_cidr_block]
  }

  // Allow inbound SSH from administrative CIDRs
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_list
  }

  // Allow any inbound on PCE front end https port
  ingress {
    from_port   = var.pce["front_end_https_port"]
    to_port     = var.pce["front_end_https_port"]
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow any inbound on PCE event service port
  ingress {
    from_port   = var.pce["front_end_event_service_port"]
    to_port     = var.pce["front_end_event_service_port"]
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.aws_vpc_name}-PCE-SG"
    Email = "brian.pitta@illumio.com"
  }
}
