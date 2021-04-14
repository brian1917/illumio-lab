# Create a template for setting the Windows admin password
data "template_file" "windows-set-user-template" {
  template = file("windows-setup.tpl")
  vars = {
    admin_password = var.windows_admin_pwd
  }
}

#Build Windows Workloads
resource "aws_instance" "windows-wkld" {
  for_each                    = var.windows_wklds
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
  user_data = data.template_file.windows-set-user-template.rendered
  lifecycle {
    ignore_changes = [user_data, ami]
  }

  tags = {
    Name  = "${var.aws_vpc_name}-${each.key}"
    Email = var.email_tag
  }
}

# Windows Workload DNS
// Use the public IP for administrative access DNS
resource "aws_route53_record" "windows-wklds-public-dns" {
  for_each = var.windows_wklds
  zone_id  = data.aws_route53_zone.zone.zone_id
  name     = "admin-${each.key}.poc"
  type     = "A"
  ttl      = "30"
  records  = [aws_instance.windows-wkld[each.key].public_ip]
}

// Use the private IP for network resolution
resource "aws_route53_record" "windows-wklds-private-dns" {
  for_each = var.windows_wklds
  zone_id  = data.aws_route53_zone.zone.zone_id
  name     = "${each.key}.poc"
  type     = "A"
  ttl      = "30"
  records  = [aws_instance.windows-wkld[each.key].private_ip]
}



