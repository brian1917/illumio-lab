output "workloads_ids" {
  value = {for k, v in aws_instance.wklds: k=>v.id}
}
output "workloads_security_groups" {
  value = {for k, v in aws_instance.wklds: k=>v.vpc_security_group_ids}
}
output "workloads_public_ips" {
  value = {for k, v in aws_instance.wklds: k=>v.public_ip}
}
output "workloads_public_dns_fqdn" {
    value = {for k,v in aws_route53_record.wklds_public_dns: k=>v.fqdn}
}
output "workloads_public_dns_ip" {
    value = {for k,v in aws_route53_record.wklds_public_dns: k=>v.records}
}