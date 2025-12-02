# Lambda Control

HTTP API for controlling the devbox spot instance via Lambda Function URL.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/status` | Get current instance status |
| POST | `/start` | Start the instance (set ASG desired capacity to 1) |
| POST | `/stop` | Stop the instance (set ASG desired capacity to 0) |

## Usage

```bash
# Get status
curl https://<function-url>/status

# Start instance
curl -X POST https://<function-url>/start

# Stop instance
curl -X POST https://<function-url>/stop
```

## Response Examples

### GET /status

```json
{
  "status": "running",
  "asg_name": "devbox-spot-asg",
  "desired_capacity": 1,
  "min_size": 0,
  "max_size": 1,
  "instances": [
    {
      "instance_id": "i-0e5180f90134f7a52",
      "state": "running",
      "instance_type": "c8gd.medium",
      "private_ip": "172.31.23.121",
      "public_ip": "13.40.33.239",
      "launch_time": "2025-12-02T03:39:45+00:00"
    }
  ]
}
```

Status values:
- `running` - Instance is running
- `stopped` - Desired capacity is 0, no instances
- `starting` - Desired capacity > 0 but no running instances yet
- `partial` - Some instances running (edge case)

### POST /start

```json
{
  "message": "Instance start initiated",
  "desired_capacity": 1
}
```

### POST /stop

```json
{
  "message": "Instance stop initiated",
  "desired_capacity": 0
}
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `function_name` | `devbox-control` | Lambda function name |
| `asg_name` | `devbox-spot-asg` | Auto Scaling Group to control |
| `auth_type` | `NONE` | `NONE` (public) or `AWS_IAM` |
| `cors_allowed_origins` | `["*"]` | Allowed CORS origins |
| `log_retention_days` | `7` | CloudWatch log retention |

## Deployment

```bash
cd terraform/lambda-control
terraform init
terraform plan
terraform apply
```

The function URL is output as `function_url`.
