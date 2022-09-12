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
variable "email_tag" {
  type        = string
  description = "Email address to be used in tags on created AWS resources."
}
variable "vpc_name" {
  type        = string
  description = "Name of VPC."
}
variable "region" {
  type        = string
  description = "AWS region where the VPC will be deployed. Example: us-east-2"
}
variable "domain" {
  type        = string
  description = "The domain to use for PCE and all workloads"
}
variable "windows_admin_pwd" {
  type        = string
  description = "Admin password for Windows workloads for RDP access"
}
variable "amis" {
  type        = map
  description = "The AMIs to find and make available for building. See variables.json for example."
}
variable "wklds" {
  type        = map
  description = "Map of workloads. See variables.json for examples."
}