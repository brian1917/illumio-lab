# Build PCE using the same CentOS image from the Linux workloads
# If the pce.cluster_type is snc, we build 1 server. If it's "mnc" we build 4 servers. If it's anything else, we don't build a server

variable "snc_base_name" {
  type    = list
  default = ["snc"]
}

variable "mnc_base_name" {
  type    = list
  default = ["core0", "core1", "data0", "data1"]
}

variable "sc_base_name" {
  type    = list
  default = ["sc1-core0", "sc1-core1", "sc1-data0", "sc1-data1", "sc2-core0", "sc2-core1", "sc2-data0", "sc2-data1"]
}

resource "aws_instance" "pce" {
  count                       = lower(var.pce["cluster_type"]) == "snc" ? 1 : lower(var.pce["cluster_type"]) == "mnc" ? 4 : lower(var.pce["cluster_type"]) == "sc" ? 8 : 0
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
  lifecycle {
    ignore_changes = [ami]
  }
  tags = {
    Name  = "${var.aws_vpc_name}-${lower(var.pce["cluster_type"]) == "snc" ? "${var.snc_base_name[count.index]}" : lower(var.pce["cluster_type"]) == "mnc" ? "${var.mnc_base_name[count.index]}" : "${var.sc_base_name[count.index]}"}"
    Email = var.email_tag
  }
}


// Create a private DNS record for each PCE node
resource "aws_route53_record" "pce-private-dns" {
  count   = lower(var.pce["cluster_type"]) == "snc" ? 1 : lower(var.pce["cluster_type"]) == "mnc" ? 4 : lower(var.pce["cluster_type"]) == "sc" ? 8 : 0
  zone_id = data.aws_route53_zone.segmentationpov.zone_id
  name    = "${lower(var.pce["cluster_type"]) == "snc" ? "${var.snc_base_name[count.index]}" : lower(var.pce["cluster_type"]) == "mnc" ? "${var.mnc_base_name[count.index]}" : "${var.sc_base_name[count.index]}"}-${var.pce["org_name"]}.poc"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.pce[count.index].private_ip]
}

// Create a public DNS record for the pce-cluster for SNC and MNC
resource "aws_route53_record" "pce-public-dns" {
  count   = lower(var.pce["cluster_type"]) != "sc" ? 1 : 0
  zone_id = data.aws_route53_zone.segmentationpov.zone_id
  name    = "${var.pce["org_name"]}.poc"
  type    = "A"
  ttl     = "30"
  records = lower(var.pce["cluster_type"]) == "mnc" ? [aws_instance.pce[0].public_ip, aws_instance.pce[1].public_ip] : [aws_instance.pce[0].public_ip]
}

// Create a public DNS record for SC clusters
resource "aws_route53_record" "sc-pce-public-dns" {
  count   = lower(var.pce["cluster_type"]) == "sc" ? 2 : 0
  zone_id = data.aws_route53_zone.segmentationpov.zone_id
  name    = "sc${count.index + 1}-${var.pce["org_name"]}.poc"
  type    = "A"
  ttl     = "30"
  records = count.index == 0 ? [aws_instance.pce[0].public_ip, aws_instance.pce[1].public_ip] : [aws_instance.pce[4].public_ip, aws_instance.pce[5].public_ip]
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
