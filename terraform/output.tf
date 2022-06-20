// Workloads
output "ansible" {
  value = [aws_instance.ansible[*].public_ip]
}
output "pce" {
  value = [aws_instance.pce[*].public_ip]
}
output "windows-wklds" {
  value = {
    for wkld in aws_instance.windows-wkld :
    wkld.tags["Name"] => [wkld.public_ip]
  }
}
output "linux-wklds" {
  value = {
    for wkld in aws_instance.linux-wkld :
    wkld.tags["Name"] => [wkld.public_ip]
  }
}
