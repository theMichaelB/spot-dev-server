variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "bucket_name" {
  description = "S3 bucket for bootstrap files"
  type        = string
  default     = "dvp-devbox"
}
