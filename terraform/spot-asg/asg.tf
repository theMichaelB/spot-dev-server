resource "aws_autoscaling_group" "devbox" {
  name                = "devbox-spot-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = data.aws_subnets.default.ids

  # Use mixed instances policy for spot
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.devbox.id
        version            = "$Latest"
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }
  }

  # Instance refresh for updates
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  # Termination policies
  termination_policies = ["OldestInstance"]

  # Health check
  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Instance warmup
  default_instance_warmup = 120

  tag {
    key                 = "Name"
    value               = var.instance_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "spot-dev-server"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
