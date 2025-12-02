"""
Lambda function to control EC2 spot instance via ASG.

Endpoints:
  GET  /status  - Get current instance status
  POST /start   - Start instance (set desired capacity to 1)
  POST /stop    - Stop instance (set desired capacity to 0)
"""

import json
import os
import boto3
from botocore.exceptions import ClientError

# Initialize clients
autoscaling = boto3.client("autoscaling")
ec2 = boto3.client("ec2")

ASG_NAME = os.environ.get("ASG_NAME", "devbox-spot-asg")


def get_asg_info():
    """Get ASG details including capacity and instance info."""
    try:
        response = autoscaling.describe_auto_scaling_groups(
            AutoScalingGroupNames=[ASG_NAME]
        )
        if not response["AutoScalingGroups"]:
            return None
        return response["AutoScalingGroups"][0]
    except ClientError as e:
        raise Exception(f"Failed to describe ASG: {e}")


def get_instance_details(instance_ids):
    """Get EC2 instance details."""
    if not instance_ids:
        return []

    try:
        response = ec2.describe_instances(InstanceIds=instance_ids)
        instances = []
        for reservation in response["Reservations"]:
            for instance in reservation["Instances"]:
                instances.append({
                    "instance_id": instance["InstanceId"],
                    "state": instance["State"]["Name"],
                    "instance_type": instance.get("InstanceType"),
                    "private_ip": instance.get("PrivateIpAddress"),
                    "public_ip": instance.get("PublicIpAddress"),
                    "launch_time": instance.get("LaunchTime", "").isoformat() if instance.get("LaunchTime") else None,
                })
        return instances
    except ClientError as e:
        raise Exception(f"Failed to describe instances: {e}")


def handle_status():
    """Handle GET /status request."""
    asg = get_asg_info()
    if not asg:
        return {
            "statusCode": 404,
            "body": json.dumps({"error": f"ASG '{ASG_NAME}' not found"})
        }

    instance_ids = [i["InstanceId"] for i in asg.get("Instances", [])]
    instances = get_instance_details(instance_ids)

    # Determine overall status
    desired = asg["DesiredCapacity"]
    running_count = sum(1 for i in instances if i["state"] == "running")

    if desired == 0:
        status = "stopped"
    elif running_count == desired:
        status = "running"
    elif running_count > 0:
        status = "partial"
    else:
        status = "starting"

    return {
        "statusCode": 200,
        "body": json.dumps({
            "status": status,
            "asg_name": ASG_NAME,
            "desired_capacity": desired,
            "min_size": asg["MinSize"],
            "max_size": asg["MaxSize"],
            "instances": instances,
        })
    }


def handle_start():
    """Handle POST /start request."""
    asg = get_asg_info()
    if not asg:
        return {
            "statusCode": 404,
            "body": json.dumps({"error": f"ASG '{ASG_NAME}' not found"})
        }

    current_desired = asg["DesiredCapacity"]
    if current_desired >= 1:
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Instance already running or starting",
                "desired_capacity": current_desired
            })
        }

    try:
        autoscaling.set_desired_capacity(
            AutoScalingGroupName=ASG_NAME,
            DesiredCapacity=1,
            HonorCooldown=False
        )
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Instance start initiated",
                "desired_capacity": 1
            })
        }
    except ClientError as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Failed to start: {e}"})
        }


def handle_stop():
    """Handle POST /stop request."""
    asg = get_asg_info()
    if not asg:
        return {
            "statusCode": 404,
            "body": json.dumps({"error": f"ASG '{ASG_NAME}' not found"})
        }

    current_desired = asg["DesiredCapacity"]
    if current_desired == 0:
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Instance already stopped",
                "desired_capacity": 0
            })
        }

    try:
        autoscaling.set_desired_capacity(
            AutoScalingGroupName=ASG_NAME,
            DesiredCapacity=0,
            HonorCooldown=False
        )
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Instance stop initiated",
                "desired_capacity": 0
            })
        }
    except ClientError as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Failed to stop: {e}"})
        }


def lambda_handler(event, context):
    """Main Lambda handler for Function URL."""
    # Extract path and method from Function URL event
    request_context = event.get("requestContext", {})
    http = request_context.get("http", {})

    method = http.get("method", event.get("httpMethod", "GET"))
    path = http.get("path", event.get("rawPath", "/"))

    # Normalize path
    path = path.rstrip("/").lower()
    if not path:
        path = "/"

    # Route requests
    if path in ("/status", "/"):
        if method == "GET":
            response = handle_status()
        else:
            response = {"statusCode": 405, "body": json.dumps({"error": "Method not allowed"})}
    elif path == "/start":
        if method == "POST":
            response = handle_start()
        else:
            response = {"statusCode": 405, "body": json.dumps({"error": "Use POST for /start"})}
    elif path == "/stop":
        if method == "POST":
            response = handle_stop()
        else:
            response = {"statusCode": 405, "body": json.dumps({"error": "Use POST for /stop"})}
    else:
        response = {
            "statusCode": 404,
            "body": json.dumps({
                "error": "Not found",
                "available_endpoints": [
                    "GET /status",
                    "POST /start",
                    "POST /stop"
                ]
            })
        }

    # Add headers
    response["headers"] = {
        "Content-Type": "application/json"
    }

    return response
