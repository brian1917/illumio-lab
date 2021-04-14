# Build the Linux workloads
resource "aws_instance" "linux-wkld" {
  for_each                    = var.linux_wklds
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

  connection {
    host        = self.public_ip
    type        = "ssh"
    user        = var.amis[each.value["ami"]].user
    password    = ""
    private_key = file(var.private_sshkey)
  }

  # Set the hostname of each server
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${each.key}",
    ]
  }
}

# Build Linux workloads DNS entries
// Use the public IP for access to workload remotely
resource "aws_route53_record" "linux-wklds-public-dns" {
  for_each = var.linux_wklds
  zone_id  = data.aws_route53_zone.zone.zone_id
  name     = "admin-${each.key}.poc"
  type     = "A"
  ttl      = "30"
  records  = [aws_instance.linux-wkld[each.key].public_ip]
}

// Use private IP for internal communication
resource "aws_route53_record" "linux-wklds-private-dns" {
  for_each = var.linux_wklds
  zone_id  = data.aws_route53_zone.zone.zone_id
  name     = "${each.key}.poc"
  type     = "A"
  ttl      = "30"
  records  = [aws_instance.linux-wkld[each.key].private_ip]
}
