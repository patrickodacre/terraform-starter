output "app_server_ip" {
  value = aws_instance.app.public_ip
}

output "app_instance_id" {
  value = aws_instance.app.id
}