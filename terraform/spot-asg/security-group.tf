resource "aws_security_group" "devbox" {
  name        = "devbox-asg-sg"
  description = "Security group for devbox ASG instances"
  vpc_id      = data.aws_vpc.default.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # No inbound rules - access via Tailscale only

  tags = {
    Name    = "devbox-asg-sg"
    Project = "spot-dev-server"
  }
}
