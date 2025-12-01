data "aws_caller_identity" "current" {}

# SSM Access Policy
resource "aws_iam_policy" "devbox_ssm_access" {
  name        = "devbox-ssm-access"
  description = "Allows access to devbox SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = flatten([
          for region in var.ssm_regions : [
            "arn:aws:ssm:${region}:${data.aws_caller_identity.current.account_id}:parameter/devbox",
            "arn:aws:ssm:${region}:${data.aws_caller_identity.current.account_id}:parameter/devbox/*"
          ]
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [for region in var.ssm_regions : "ssm.${region}.amazonaws.com"]
          }
        }
      }
    ]
  })
}

# S3 Access Policy
resource "aws_iam_policy" "devbox_s3_access" {
  name        = "devbox-s3-access"
  description = "Allows access to devbox S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [for bucket in var.s3_buckets : "arn:aws:s3:::${bucket}"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [for bucket in var.s3_buckets : "arn:aws:s3:::${bucket}/*"]
      }
    ]
  })
}

# Route53 Access Policy
resource "aws_iam_policy" "devbox_route53_access" {
  name        = "devbox-route53-access"
  description = "Allows access to Route53 for DNS updates"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetHostedZone"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}",
          "arn:aws:route53:::change/*"
        ]
      }
    ]
  })
}

# STS Web Identity Token Policy (for Tailscale OIDC)
resource "aws_iam_policy" "devbox_sts_web_identity" {
  name        = "devbox-sts-web-identity"
  description = "Allows getting web identity tokens for Tailscale OIDC authentication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowGetWebIdentityToken"
        Effect   = "Allow"
        Action   = "sts:GetWebIdentityToken"
        Resource = "*"
        Condition = {
          StringEquals = {
            "sts:DurationSeconds" = "60"
          }
        }
      }
    ]
  })
}
