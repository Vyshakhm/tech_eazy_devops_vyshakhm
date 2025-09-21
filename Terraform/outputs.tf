output "instance_id" {
  value = aws_instance.app.id
  description = "EC2 Instance ID"
}

output "public_ip" {
  value = aws_instance.app.public_ip
  description = "Public IP of the instance (use this in browser or for SSH)"
}
