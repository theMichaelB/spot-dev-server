resource "aws_launch_template" "devbox" {
  name          = "devbox-spot-lt"
  description   = "Launch template for devbox spot instances"
  image_id      = data.aws_ami.debian.id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = base64encode(file("${path.module}/../../cloud-init/userdata.yaml"))

  iam_instance_profile {
    name = data.aws_iam_instance_profile.devbox.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.devbox.id]
    delete_on_termination       = true
  }

  # Require IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = var.instance_name
      Project = "spot-dev-server"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.instance_name}-volume"
      Project = "spot-dev-server"
    }
  }

  tags = {
    Name    = "devbox-spot-lt"
    Project = "spot-dev-server"
  }
}
