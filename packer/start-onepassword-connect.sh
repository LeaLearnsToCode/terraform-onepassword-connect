#!/usr/bin/env bash

# /home/ec2-user/start-onepassword-connect.sh

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 15")
SECRET_ARN=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  -v http://169.254.169.254/latest/meta-data/tags/instance/onepassword-secret-arn)

# shellcheck disable=SC2005
echo "$(/usr/bin/aws secretsmanager get-secret-value \
  --region us-west-2 \
  --secret-id "${SECRET_ARN}" \
  --query "SecretString" \
  --output text)" \
  > /home/ec2-user/onepassword-connect/1password-credentials.json

/home/ec2-user/.local/bin/docker-compose up
