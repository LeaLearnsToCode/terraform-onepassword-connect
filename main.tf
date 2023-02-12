variable "onepassword_credentials_json" {
  type = string
}

variable "app_env" {
  type = string
}

data "aws_ami" "onepassword_ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["onepassword-connect-*"]
  }

  filter {
    name   = "tag:created-with"
    values = ["automation"]
  }


  filter {
    name   = "tag:app-env"
    values = [var.app_env]
  }

  filter {
    name   = "tag:promoted"
    values = ["true", "false"]
  }
}

resource "aws_secretsmanager_secret" "onepassword_connect_server" {
  name_prefix = "onepassword-connect-server-"
}

resource "aws_secretsmanager_secret_version" "onepassword_credentials_json" {
  secret_id     = aws_secretsmanager_secret.onepassword_connect_server.id
  secret_string = var.onepassword_credentials_json
}

resource "aws_iam_role" "onepassword_connect_server" {
  name_prefix = "onepassword-connect-server-"

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
    name = "onepassword-secret-access"

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
  name_prefix = "onepassword-server-"
  role        = aws_iam_role.onepassword_connect_server.name
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "onepassword-connect-vpc"
  }
}

resource "aws_subnet" "onepassword_connect" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "onepassword-connect-subnet"
  }
}

resource "aws_security_group" "onepassword_connect_server" {
  name_prefix = "onepassword-connect-server-"
  description = "Onepassword Server"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "instance" {
  ami                    = data.aws_ami.onepassword_ami.id
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.onepassword_connect_server.name
  subnet_id              = aws_subnet.onepassword_connect.id
  vpc_security_group_ids = [
    aws_security_group.onepassword_connect_server.id
  ]
}

output "onepassword_connect_secret_arn" {
  value = aws_secretsmanager_secret_version.onepassword_credentials_json.arn
}

output "onepassword_connect_instance_profile_id" {
  value = aws_iam_instance_profile.onepassword_connect_server.id
}

