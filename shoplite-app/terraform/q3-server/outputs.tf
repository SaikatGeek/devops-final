output "public_ip" {
  description = "The server's address (SERVER in linux/evidence/commands.md)."
  value       = aws_instance.server.public_ip
}

output "ssh" {
  description = "How to log in as the default user."
  value       = "ssh ubuntu@${aws_instance.server.public_ip}"
}

output "instance_id" {
  description = "EC2 instance id."
  value       = aws_instance.server.id
}
