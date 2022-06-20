# Variables are declared here for Terraform with descriptions and examples.
# Values should be assigned in variables.json and terraform commands should use -var-file=variables.json.
# The JSON input allows for flexibility for variables to be used in other integrations (e.g., Ansible, bash scripts, etc.)

variable "profile" {
  type        = string
  description = "AWS profile to use"
}
variable "variables_file" {
  type        = string
  description = "JSON variable file that will be moved to the PCE server for configuration values."
}
variable "aws_region" {
  type        = string
  description = "AWS region where the VPC will be deployed. Example: us-east-2"
}
variable "email_tag" {
  type        = string
  description = "Email address to be used in tags on created AWS resources."
}
variable "aws_vpc_name" {
  type        = string
  description = "Name of the VPC. This will be used in most tags of other resources. Example: bep-p-lab"
}
variable "domain" {
  type        = string
  description = "The domain to use for PCE and all workloads"
}
variable "vpc_cidr_block" {
  type        = string
  description = "Example: 192.168.128.0/24"
}
variable "private_sshkey" {
  type        = string
  description = "Path to the private ssh key. Example: ~/.ssh/id_rsa"
}
variable "public_sshkey" {
  type        = string
  description = "Path to the private ssh key. Example: ~/.ssh/id_rsa.pub"
}
variable "windows_admin_pwd" {
  type        = string
  description = "Admin password for Windows workloads for RDP access"
}
variable "admin_cidr_list" {
  type        = list
  description = "List of CIDRs that will have RDP/SSH access to the workloads."
}
variable "amis" {
  type        = map
  description = "The AMIs to find and make available for building. See variables.json for example."
}
variable "subnets" {
  type        = map
  description = "Key-value pairs for subnets. See variables.json for examples."
}
variable "linux_wklds" {
  type        = map
  description = "Map of linux workloads. See variables.json for examples."
}
variable "additional_pces" {
  type        = map
  description = "Map of additional pces. See variables.json for examples."
}
variable "windows_wklds" {
  type        = map
  description = "Map of for Windows workloads. See variables.json for examples."
}
variable "kubernetes" {
  type        = map
  description = "Key-value pairs for Kubernetes nodes. See variables.json for examples."
}
variable "ansible_server" {
  type        = map
  description = "Key-value pairs for the ansible server. See variables.json for examples."
}
variable "pce" {
  type        = map
  description = "Key-value pairs for the PCE server. See variables.json for examples."
}
