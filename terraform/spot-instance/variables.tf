variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "c8gd.medium"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "devbox"
}

variable "instance_name" {
  description = "Name tag for the instance"
  type        = string
  default     = "devbox-spot"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 16
}
