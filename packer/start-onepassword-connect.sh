#!/usr/bin/env bash

# shellcheck disable=SC2005
echo "$(aws secretsmanager get-secret-value \
  --region us-west-2 \
  --secret-id "${ONEPASSWORD_SECRET_ID}" \
  --query "SecretString" \
  --output text | jq -r .\"1password-credentials.json\")" \
  > /home/ec2-user/onepassword-connect/1password-credentials.json

/home/ec2-user/.local/bin/docker-compose up
