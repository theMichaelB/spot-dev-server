resource "aws_security_group" "devbox" {
  name        = "devbox-spot-sg"
  description = "Security group for devbox spot instance"
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
    Name    = "devbox-spot-sg"
    Project = "spot-dev-server"
  }
}
