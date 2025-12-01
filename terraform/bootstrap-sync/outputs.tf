output "bootstrap_s3_uri" {
  description = "S3 URI for bootstrap.sh"
  value       = "s3://${var.bucket_name}/${aws_s3_object.bootstrap.key}"
}

output "scripts_uploaded" {
  description = "List of uploaded script files"
  value       = [for k, v in aws_s3_object.scripts : v.key]
}

output "ansible_uploaded" {
  description = "List of uploaded ansible files"
  value       = [for k, v in aws_s3_object.ansible : v.key]
}

output "scripts_s3_uri" {
  description = "S3 URI for scripts"
  value       = "s3://${var.bucket_name}/scripts/"
}

output "ansible_s3_uri" {
  description = "S3 URI for ansible"
  value       = "s3://${var.bucket_name}/ansible/"
}
