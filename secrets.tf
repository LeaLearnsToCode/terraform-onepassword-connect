resource "aws_secretsmanager_secret" "onepassword_connect_server" {
  name_prefix = "${var.app_env}-onepassword-server-"
}

resource "aws_secretsmanager_secret_version" "onepassword_credentials_json" {
  secret_id     = aws_secretsmanager_secret.onepassword_connect_server.id
  secret_string = var.onepassword_credentials_json
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
          Resource = aws_secretsmanager_secret.onepassword_connect_server.arn
        },
      ]
    })
  }
}

resource "aws_iam_instance_profile" "onepassword_connect_server" {
  name_prefix = "${var.app_env}-onepassword-"
  role        = aws_iam_role.onepassword_connect_server.name
}
