variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "devbox-control"
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group to control"
  type        = string
  default     = "devbox-spot-asg"
}

variable "auth_type" {
  description = "Authorization type for Lambda Function URL (NONE or AWS_IAM)"
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["NONE", "AWS_IAM"], var.auth_type)
    error_message = "auth_type must be NONE or AWS_IAM"
  }
}

variable "cors_allowed_origins" {
  description = "Allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
