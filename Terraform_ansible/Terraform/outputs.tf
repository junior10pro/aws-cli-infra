output "instance_hostname" {
  description = "Private DNS name of the EC2 instance."
  value       = aws_instance.app_server.private_dns
}

output "vm_ip_publique" {
  value = aws_instance.app_server.public_ip
}
