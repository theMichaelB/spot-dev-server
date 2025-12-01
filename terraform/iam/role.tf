# IAM Role for EC2 Spot instances
resource "aws_iam_role" "devbox_spot_common" {
  name = "devbox-spot-common"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "devbox-spot-common"
    Project = "spot-dev-server"
  }
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.devbox_spot_common.name
  policy_arn = aws_iam_policy.devbox_ssm_access.arn
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.devbox_spot_common.name
  policy_arn = aws_iam_policy.devbox_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "route53_access" {
  role       = aws_iam_role.devbox_spot_common.name
  policy_arn = aws_iam_policy.devbox_route53_access.arn
}

resource "aws_iam_role_policy_attachment" "sts_web_identity" {
  role       = aws_iam_role.devbox_spot_common.name
  policy_arn = aws_iam_policy.devbox_sts_web_identity.arn
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "devbox_spot_common" {
  name = "devbox-spot-common"
  role = aws_iam_role.devbox_spot_common.name
}
