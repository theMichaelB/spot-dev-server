resource "aws_spot_instance_request" "devbox" {
  ami                         = data.aws_ami.debian.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.devbox.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  iam_instance_profile        = data.aws_iam_instance_profile.devbox.name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/../../cloud-init/userdata.yaml")

  # Spot configuration
  spot_type                      = "one-time"
  instance_interruption_behavior = "terminate"
  wait_for_fulfillment           = true

  # Instance behavior
  instance_initiated_shutdown_behavior = "terminate"

  # Require IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name    = var.instance_name
    Project = "spot-dev-server"
  }
}

# Propagate tags to the actual EC2 instance
resource "aws_ec2_tag" "name" {
  resource_id = aws_spot_instance_request.devbox.spot_instance_id
  key         = "Name"
  value       = var.instance_name
}

resource "aws_ec2_tag" "project" {
  resource_id = aws_spot_instance_request.devbox.spot_instance_id
  key         = "Project"
  value       = "spot-dev-server"
}
