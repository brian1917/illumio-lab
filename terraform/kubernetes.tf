# Build the Linux workloads
resource "aws_instance" "kubernetes-nodes" {
  for_each                    = var.kubernetes
  ami                         = data.aws_ami.amis[each.value["ami"]].id
  instance_type               = each.value["type"]
  vpc_security_group_ids      = [aws_security_group.lab-rules.id]
  subnet_id                   = aws_subnet.subnet[each.value["subnet"]].id
  associate_public_ip_address = true
  key_name                    = "${var.aws_vpc_name}-key"
  root_block_device {
    delete_on_termination = true
    volume_size           = each.value["volume_size_gb"]
  }
  lifecycle {
    ignore_changes = [ami]
  }
  tags = {
    Name  = "${var.aws_vpc_name}-${each.key}"
    Email = var.email_tag
  }
}

# Build Linux workloads DNS entries
// Use the public IP for access to workload remotely
resource "aws_route53_record" "kubernetes-public-dns" {
  for_each = var.kubernetes
  zone_id  = data.aws_route53_zone.segmentationpov.zone_id
  name     = "admin-${each.key}.poc"
  type     = "A"
  ttl      = "30"
  records  = [aws_instance.kubernetes-nodes[each.key].public_ip]
}

// Use private IP for internal communication
resource "aws_route53_record" "kubernetes-private-dns" {
  for_each = var.kubernetes
  zone_id  = data.aws_route53_zone.segmentationpov.zone_id
  name     = "${each.key}.poc"
  type     = "A"
  ttl      = "30"
  records  = [aws_instance.kubernetes-nodes[each.key].private_ip]
}
