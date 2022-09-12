output "vpc_id" {
  value = [aws_vpc.vpc.id]
}
output "subnet_ids" {
   value = {for k, v in aws_subnet.subnet: k=>v.id}
}
output "key_pair" {
  value = [aws_key_pair.auth.key_name]
}
output "security_group_lab-workload" {
  value = [aws_security_group.lab_workload.id]
}
output "security_group_pce" {
  value = [aws_security_group.pce.id]
}
output "security_group_open" {
  value = [aws_security_group.open.id]
}
