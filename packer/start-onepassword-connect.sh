#!/usr/bin/env bash

aws secretsmanager get-secret-value \
  --region us-west-2 \
  --secret-id "${ONEPASSWORD_SECRET_ID}" \
  --query "SecretString" \
  --output text | jq -r .\"1password-credentials.json\" \
  > /home/ec2-user/onepassword-connect/1password-credentials.json

docker-compose up -d
