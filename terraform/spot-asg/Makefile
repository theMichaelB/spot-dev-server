.PHONY: start stop status plan apply destroy init

ASG_NAME := devbox-spot-asg
REGION := eu-west-2

.DEFAULT_GOAL := status

# Start the instance (set desired capacity to 1)
start:
	aws autoscaling set-desired-capacity \
		--auto-scaling-group-name $(ASG_NAME) \
		--desired-capacity 1 \
		--region $(REGION)
	@echo "Starting instance..."

# Stop the instance (set desired capacity to 0)
stop:
	aws autoscaling set-desired-capacity \
		--auto-scaling-group-name $(ASG_NAME) \
		--desired-capacity 0 \
		--region $(REGION)
	@echo "Stopping instance..."

# Check ASG and instance status
status:
	@aws autoscaling describe-auto-scaling-groups \
		--auto-scaling-group-names $(ASG_NAME) \
		--region $(REGION) \
		--query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:Instances[*].{Id:InstanceId,State:LifecycleState}}' \
		--output table

# Terraform commands
init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply

destroy:
	terraform destroy
