output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.control.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.control.arn
}

output "function_url" {
  description = "Lambda Function URL endpoint"
  value       = aws_lambda_function_url.control.function_url
}

output "role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.lambda.name
}
