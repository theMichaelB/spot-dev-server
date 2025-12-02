#!/bin/bash

set -e

terraform taint "aws_spot_instance_request.devbox"
terraform apply -auto-approve -var="instance_profile_name=devbox-spot-admin"
