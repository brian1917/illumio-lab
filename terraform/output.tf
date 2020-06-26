// Workloads
output "ansible" {
    value = [aws_instance.ansible[*].id]
}
output "pce" {
    value = [aws_instance.pce[*].id]
}
output "windows-wklds" {
    value = {
        for wkld in aws_instance.windows-wkld:
        wkld.tags["Name"] => [wkld.id]
    }
}
output "linux-wklds" {
    value = {
        for wkld in aws_instance.linux-wkld:
        wkld.tags["Name"] => [wkld.id]
    }
}