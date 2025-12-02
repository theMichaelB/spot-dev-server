# Lambda function and Function URL

# Archive the source code
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/dist/lambda.zip"
}

# CloudWatch Log Group (create before Lambda to control retention)
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name    = "devbox-control-logs"
    Project = "spot-dev-server"
  }
}

# Lambda function
resource "aws_lambda_function" "control" {
  function_name    = var.function_name
  description      = "Control devbox spot instance (start/stop/status)"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  timeout          = 30
  memory_size      = 128

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      ASG_NAME = var.asg_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_logging,
    aws_iam_role_policy_attachment.asg_control,
  ]

  tags = {
    Name    = var.function_name
    Project = "spot-dev-server"
  }
}

# Lambda Function URL (public access)
resource "aws_lambda_function_url" "control" {
  function_name      = aws_lambda_function.control.function_name
  authorization_type = var.auth_type

  cors {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "POST"]
    allow_headers = ["Content-Type"]
    max_age       = 3600
  }
}

# Allow public access when using NONE auth type
resource "aws_lambda_permission" "function_url" {
  count = var.auth_type == "NONE" ? 1 : 0

  statement_id           = "AllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.control.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
