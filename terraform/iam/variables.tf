variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "ssm_regions" {
  description = "Regions where SSM parameters are stored"
  type        = list(string)
  default     = ["us-east-1", "eu-west-2"]
}

variable "s3_buckets" {
  description = "S3 buckets for devbox access"
  type        = list(string)
  default     = ["dvp.sh", "dvp-devbox"]
}

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = "Z05005861OEGFVGL0OT2I"
}
