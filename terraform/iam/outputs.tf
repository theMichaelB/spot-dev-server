output "role_arn" {
  description = "ARN of the devbox-spot-common role"
  value       = aws_iam_role.devbox_spot_common.arn
}

output "role_name" {
  description = "Name of the devbox-spot-common role"
  value       = aws_iam_role.devbox_spot_common.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile"
  value       = aws_iam_instance_profile.devbox_spot_common.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile"
  value       = aws_iam_instance_profile.devbox_spot_common.name
}

output "policy_arns" {
  description = "ARNs of all created policies"
  value = {
    ssm_access       = aws_iam_policy.devbox_ssm_access.arn
    s3_access        = aws_iam_policy.devbox_s3_access.arn
    route53_access   = aws_iam_policy.devbox_route53_access.arn
    sts_web_identity = aws_iam_policy.devbox_sts_web_identity.arn
  }
}
