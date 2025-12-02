# IAM role for Lambda function

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Trust policy allowing Lambda to assume the role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Lambda execution role
resource "aws_iam_role" "lambda" {
  name               = "devbox-control-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name    = "devbox-control-lambda"
    Project = "spot-dev-server"
  }
}

# Policy for ASG control (start/stop)
data "aws_iam_policy_document" "asg_control" {
  # Describe ASGs
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
    ]
    resources = ["*"]
  }

  # Set desired capacity on the specific ASG
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:UpdateAutoScalingGroup",
    ]
    resources = [
      "arn:aws:autoscaling:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.asg_name}"
    ]
  }

  # Describe EC2 instances for status
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "asg_control" {
  name        = "devbox-control-asg-policy"
  description = "Allow Lambda to control devbox ASG"
  policy      = data.aws_iam_policy_document.asg_control.json

  tags = {
    Name    = "devbox-control-asg-policy"
    Project = "spot-dev-server"
  }
}

resource "aws_iam_role_policy_attachment" "asg_control" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.asg_control.arn
}

# CloudWatch Logs policy for Lambda
data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name}:*"
    ]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "devbox-control-lambda-logging"
  description = "Allow Lambda to write CloudWatch logs"
  policy      = data.aws_iam_policy_document.lambda_logging.json

  tags = {
    Name    = "devbox-control-lambda-logging"
    Project = "spot-dev-server"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}
