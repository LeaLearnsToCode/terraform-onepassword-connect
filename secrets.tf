resource "aws_kms_key" "secret" {
  enable_key_rotation = true
}

resource "aws_secretsmanager_secret" "onepassword_connect_server" {
  name_prefix = "${var.app_env}-onepassword-server-"
  kms_key_id  = aws_kms_key.secret.id
}

resource "aws_secretsmanager_secret_version" "onepassword_credentials_json" {
  secret_id     = aws_secretsmanager_secret.onepassword_connect_server.id
  secret_string = var.ONEPASSWORD_CREDENTIALS_JSON
}

resource "aws_secretsmanager_secret" "cloudflared" {
  name_prefix = "${var.app_env}-cloudflared-secret-"
  kms_key_id  = aws_kms_key.secret.id
}

resource "aws_secretsmanager_secret_version" "cloudflared_secret" {
  secret_id     = aws_secretsmanager_secret.cloudflared.id
  secret_string = random_id.tunnel_secret.b64_std
}

resource "aws_iam_role" "onepassword_connect_server" {
  name_prefix         = "${var.app_env}-onepassword-server-"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.app_env}-onepassword-secret-access"

    policy = jsonencode({
      Version   = "2012-10-17"
      Statement = [
        {
          Action   = ["secretsmanager:GetSecretValue"]
          Effect   = "Allow"
          Resource = [
            aws_secretsmanager_secret.onepassword_connect_server.arn,
            aws_secretsmanager_secret.cloudflared.arn
          ]
        },
        {
          Action = [
            "kms:Decrypt",
            #"kms:DescribeKey"
          ]
          Effect   = "Allow"
          Resource = [
            aws_kms_key.secret.arn
          ]
        },
      ]
    })
  }
}

resource "aws_iam_instance_profile" "onepassword_connect_server" {
  name_prefix = "${var.app_env}-onepassword-"
  role        = aws_iam_role.onepassword_connect_server.name
}
