# Find all of the AMIs
data "aws_ami" "amis" {
  for_each    = var.amis
  owners      = [each.value["owner"]]
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = [each.value["ami"]]
  }
}


