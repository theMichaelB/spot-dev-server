output "spot_request_id" {
  description = "Spot instance request ID"
  value       = aws_spot_instance_request.devbox.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_spot_instance_request.devbox.spot_instance_id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_spot_instance_request.devbox.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_spot_instance_request.devbox.private_ip
}

output "ami_id" {
  description = "AMI ID used"
  value       = data.aws_ami.debian.id
}

output "ami_name" {
  description = "AMI name"
  value       = data.aws_ami.debian.name
}
