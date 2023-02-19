variable "ONEPASSWORD_CREDENTIALS_JSON" {
  type = string
}

variable "CLOUDFLARE_ACCOUNT_ID" {
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
  subnet_id              = aws_subnet.private.id
  monitoring             = true
  vpc_security_group_ids = [
    aws_security_group.onepassword_connect_server.id
  ]

  metadata_options {
    http_endpoint          = "enabled"
    http_tokens            = "required"
    instance_metadata_tags = "enabled"
  }

  tags = {
    onepassword-secret-arn = aws_secretsmanager_secret_version.onepassword_credentials_json.arn
    cloudflared-secret-arn = aws_secretsmanager_secret_version.cloudflared_secret.arn
  }

  user_data_replace_on_change = true
  user_data                   = templatefile("./userdata.sh", {
    domain      = data.cloudflare_zone.domain.name,
    account     = var.CLOUDFLARE_ACCOUNT_ID,
    tunnel_id   = cloudflare_tunnel.onepassword.id,
    tunnel_name = cloudflare_tunnel.onepassword.name
  })
}
