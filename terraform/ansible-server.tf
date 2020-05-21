# Build and provision the Ansible workload

# Generate the hosts file
resource "null_resource" "hosts-file-generator" {
  count = var.ansible_server["build"] == "true" ? 1 : 0
  provisioner "local-exec" {
    command = "../ansible/build-ansible-hosts.sh"
  }
}

# Build the EC2 instance
resource "aws_instance" "ansible" {
  count                       = var.ansible_server["build"] == "true" ? 1 : 0
  depends_on                  = [null_resource.hosts-file-generator]
  ami                         = "ami-08e4d22f3042bfe58"
  instance_type               = var.ansible_server["type"]
  vpc_security_group_ids      = [aws_security_group.lab-rules.id]
  subnet_id                   = aws_subnet.subnet[var.ansible_server["subnet"]].id
  associate_public_ip_address = true
  key_name                    = "${var.aws_vpc_name}-key"
  root_block_device {
    delete_on_termination = true
    volume_size           = var.ansible_server["volume_size_gb"]
  }
  lifecycle {
    ignore_changes = [ami]
  }
  tags = {
    Name  = "${var.aws_vpc_name}-${var.ansible_server["name"]}"
    Email = var.email_tag
  }
}

# Build the ansible DNS entries
// Use the public IP for access to workload remotely
resource "aws_route53_record" "ansible-public-dns" {
  count   = var.ansible_server["build"] == "true" ? 1 : 0
  zone_id = data.aws_route53_zone.segmentationpov.zone_id
  name    = "admin-${var.ansible_server["name"]}.${data.aws_route53_zone.segmentationpov.name}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.ansible[0].public_ip]
}

// Use private IP for internal communication
resource "aws_route53_record" "ansible-private-dns" {
  count   = var.ansible_server["build"] == "true" ? 1 : 0
  zone_id = data.aws_route53_zone.segmentationpov.zone_id
  name    = "${var.ansible_server["name"]}.${data.aws_route53_zone.segmentationpov.name}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.ansible[0].private_ip]
}

// Provision the ansible server as a null resource so we can get Ansible DNS set up first (not required, but nice for when ansible fails and exits terraform)
resource "null_resource" "trigger_pce-build_playbook" {
  count      = var.ansible_server["build"] == "true" ? 1 : 0
  depends_on = [aws_route53_record.ansible-private-dns, aws_route53_record.ansible-public-dns]
  connection {
    host        = aws_instance.ansible[0].public_ip
    type        = "ssh"
    user        = var.amis[var.ansible_server["ami"]].user
    password    = ""
    private_key = file(var.private_sshkey)
  }

  # Uncomment this section if you need to provision the ansible server
  # You'd do this if you're using a plain CentOS AMI instead of the AMI configured with Ansible already. 
  # The AMI with ansible saves a lot of build time.
  /**
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install epel-release",
      "sudo yum -y update",
      "sudo yum -y install ansible python-pip pip",
      "sudo pip install pywinrm",
    ]
  }
  **/

  # Copy SSH key directory
  provisioner "file" {
    source      = var.private_sshkey
    destination = "/home/centos/.ssh/id_rsa"
  }

  # Set hostname, add SSH key with right permissions and change ownership of ansible hosts file
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${var.ansible_server["name"]}",
      "echo 'IdentityFile ~/.ssh/id_rsa' >> /home/centos/.ssh/config",
      "chmod 600 ~/.ssh/config",
      "chmod 600 ~/.ssh/id_rsa",
      "sudo chown centos /etc/ansible/hosts"
    ]
  }

  # Copy the ansible folder
  provisioner "file" {
    source      = "../ansible"
    destination = "/home/centos"
  }

  # Copy the variables JSON file
  provisioner "file" {
    source      = var.variables_file
    destination = "/home/centos/ansible/variables.json"
  }

  # Copy the hosts file to the ansible server
  provisioner "file" {
    source      = "../ansible/hosts"
    destination = "/etc/ansible/hosts"
  }

  # Copy the VEN bundle
  provisioner "file" {
    source      = var.pce["ven_bundle"]
    destination = "/home/centos/ansible/pce-build/roles/pce/files/${basename(var.pce["ven_bundle"])}"
  }

  # Copy the PCE RPM
  provisioner "file" {
    source      = var.pce["rpm"]
    destination = "/home/centos/ansible/pce-build/roles/pce/files/${basename(var.pce["rpm"])}"
  }

  # Copy the PCE RPM
  provisioner "file" {
    source      = var.pce["ui_rpm"]
    destination = "/home/centos/ansible/pce-build/roles/pce/files/${basename(var.pce["ui_rpm"])}"
  }

  # Copy the cert
  provisioner "file" {
    source      = var.pce["cert"]
    destination = "/home/centos/ansible/pce-build/roles/pce/files/${basename(var.pce["cert"])}"
  }

  # Copy the key
  provisioner "file" {
    source      = var.pce["key"]
    destination = "/home/centos/ansible/pce-build/roles/pce/files/${basename(var.pce["key"])}"
  }

  # Build the PCE

  provisioner "remote-exec" {
    inline = [
      "ansible-playbook ansible/pce-build/site.yml -f 20 -e @ansible/variables.json"
    ]
  }
}
