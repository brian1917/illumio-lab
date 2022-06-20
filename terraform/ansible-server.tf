# Build and provision the Ansible workload

# Generate the hosts file
resource "null_resource" "hosts-file-generator" {
  count = var.ansible_server["build"] == "true" ? 1 : 0
  provisioner "local-exec" {
    command = "../ansible/build-ansible-hosts.sh ${var.variables_file}"
  }
}

# Build the EC2 instance
resource "aws_instance" "ansible" {
  count                       = var.ansible_server["build"] == "true" ? 1 : 0
  depends_on                  = [null_resource.hosts-file-generator, aws_instance.pce, aws_instance.linux-wkld, aws_instance.windows-wkld]
  ami                         = "ami-08e4d22f3042bfe58" # Ohio. For virginiam use ami-0af2b43b4a197a67d
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
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "admin-${var.ansible_server["name"]}.poc"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.ansible[0].public_ip]
}

// Use private IP for internal communication
resource "aws_route53_record" "ansible-private-dns" {
  count   = var.ansible_server["build"] == "true" ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${var.ansible_server["name"]}.poc"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.ansible[0].private_ip]
}

resource "null_resource" "run_ansible_play_books" {
  count      = var.ansible_server["build"] == "true" ? 1 : 0
  depends_on = [aws_route53_record.ansible-public-dns, aws_route53_record.ansible-private-dns]

  // Connect using the Public IP address
  connection {
    host        = aws_instance.ansible[0].public_ip
    type        = "ssh"
    user        = var.amis[var.ansible_server["ami"]].user
    password    = ""
    private_key = file(var.private_sshkey)
  }

  /**
  Uncomment this section if you need to provision the ansible server
  You'd do this if you're using a plain CentOS AMI instead of the AMI configured with Ansible already. 
  The AMI with ansible saves a lot of build time.
  **/
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

  # Run some commands to prep the ansible server
  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${var.ansible_server["name"]}",   # Set hostname
      "echo 'IdentityFile ~/.ssh/id_rsa' >> /home/centos/.ssh/config", # Add identity file to ssh config
      "chmod 600 ~/.ssh/config ~/.ssh/id_rsa",                         # Update permissions of config file and private SSH Key.
      "sudo mv /home/centos/ansible/hosts /etc/ansible/hosts",         # Move the Hosts file from the Ansible folder to default location
      "pip install dnspython",                                         # This is to do reverse DNS lookup in Ansible. We should work it into Ansible AMI soon.
      "sudo yum install -y wget unzip"                                 # Download and unzip workloader. We should work it into the Ansible AMI soon.
    ]
    on_failure = continue
  }

  # Build the PCE
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook ansible/pce-build/site.yml -e @ansible/variables.json --skip-tags hardening",
      "ansible-playbook ansible/wkld-setup/site.yml -e @ansible/variables.json",
      "ansible-playbook ansible/ven-repo-install/site.yml -e @ansible/variables.json",
      "ansible-playbook ansible/kubernetes/site.yml -e @ansible/variables.json"
    ]
    on_failure = continue
  }

}

