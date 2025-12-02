output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.devbox.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.devbox.latest_version
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.devbox.name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = aws_autoscaling_group.devbox.arn
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.devbox.id
}

output "ami_id" {
  description = "AMI ID used"
  value       = data.aws_ami.debian.id
}

output "ami_name" {
  description = "AMI name"
  value       = data.aws_ami.debian.name
}
