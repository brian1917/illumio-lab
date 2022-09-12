# Create the key pair for workloads and PCE
resource "aws_key_pair" "auth" {
  key_name   = var.vpc_name
  public_key = file(var.public_sshkey)
  tags = {
    Email = var.email_tag
  }
}