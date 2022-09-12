# Create a template for setting the Windows admin password
data "template_file" "windows-set-user-template" {
  template = file("windows-setup.tpl")
  vars = {
    admin_password = var.windows_admin_pwd
  }
}

# Get the DNS zone
data "aws_route53_zone" "zone" {
  name         = var.domain
  private_zone = false
}

# Get security groups
data "aws_security_group" "lab_workload_sg" {
  name = "lab_workload"
}
data "aws_security_group" "pce_sg" {
  name = "pce"
}
data "aws_security_group" "open_sg" {
  name = "open"
}

# Get Subnets
data "aws_subnet" "subnet-1" {
  filter {
    name = "tag:Name"
    values = ["subnet-1"]
  }

}
data "aws_subnet" "subnet-2" {
  filter {
    name = "tag:Name"
    values = ["subnet-2"]
  }
}
data "aws_subnet" "subnet-3" {
  filter {
    name = "tag:Name"
    values = ["subnet-3"]
  }
}
data "aws_subnet" "subnet-4" {
  filter {
    name = "tag:Name"
    values = ["subnet-4"]
  }
}

# Build workloads
resource "aws_instance" "wklds" {
  for_each                    = var.wklds
  ami                         = data.aws_ami.amis[each.value["ami"]].id
  instance_type               = each.value["type"]
  vpc_security_group_ids      = each.value["open_sg"] == "true" ? [data.aws_security_group.open_sg.id,data.aws_security_group.lab_workload_sg.id] : each.value["pce_sg"] == "true" ? [data.aws_security_group.pce_sg.id, data.aws_security_group.lab_workload_sg.id] : [data.aws_security_group.lab_workload_sg.id]
  subnet_id                   = each.value["subnet"] == "subnet-1" ? data.aws_subnet.subnet-1.id : each.value["subnet"] == "subnet-2" ? data.aws_subnet.subnet-2.id : each.value["subnet"] == "subnet-3" ? data.aws_subnet.subnet-3.id : each.value["subnet"] == "subnet-4" ? data.aws_subnet.subnet-4.id : each.value["subnet"]
  associate_public_ip_address = true
  key_name                    = var.vpc_name
  root_block_device {
    delete_on_termination = true
    volume_size           = each.value["volume_size_gb"]
  }
  user_data = data.template_file.windows-set-user-template.rendered
  lifecycle {
    ignore_changes = [user_data, ami]
  }
  tags = {
    Email = var.email_tag
    Name = each.key
  }
}

# Add DNS for public and private IPs
resource "aws_route53_record" "wklds_public_dns" {
  for_each = var.wklds
  zone_id  = data.aws_route53_zone.zone.zone_id
  name     = "${each.key}.poc"
  type     = "A"
  ttl      = "30"
  records  = [aws_instance.wklds[each.key].public_ip]
}

resource "aws_route53_record" "wklds_private_dns" {
  for_each = var.wklds
  zone_id  = data.aws_route53_zone.zone.zone_id
  name     = "${each.key}-priv.poc"
  type     = "A"
  ttl      = "30"
  records  = [aws_instance.wklds[each.key].private_ip]
}



