#!/usr/bin/env bash

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 15")
SECRET_ARN=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
        -v http://169.254.169.254/latest/meta-data/tags/instance/cloudflared-secret-arn)

echo "$SECRET_ARN" > /etc/cloudflared/test

SECRET=$(/usr/bin/aws secretsmanager get-secret-value \
        --region us-west-2 \
        --secret-id "$SECRET_ARN" \
        --query "SecretString" \
        --output text)

cat >/etc/cloudflared/cert.json <<EOF
{
    "AccountTag"   : "${account}",
    "TunnelID"     : "${tunnel_id}",
    "TunnelName"   : "${tunnel_name}",
    "TunnelSecret" : "$${SECRET}"
}
EOF

cat >/etc/cloudflared/config.yml <<"EOF"
tunnel: ${tunnel_id}
credentials-file: /etc/cloudflared/cert.json
logfile: /var/log/cloudflared.log
loglevel: info
EOF
