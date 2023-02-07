packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "dockerhub_user" {
  type = string
}

variable "dockerhub_pat" {
  type      = string
  sensitive = true
}

variable "onepassword_secret_id" {
  type      = string
  sensitive = false
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "onepassword_connect" {
  ami_name      = "onepassword-connect-${local.timestamp}"
  instance_type = "t3.micro"
  region        = "us-west-2"
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-minimal-hvm-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["137112412989"]
  }
  ssh_username = "ec2-user"
}

build {
  name    = "onepassword-connect"
  #deprecate_at = timeadd(timestamp(), "525600m") # 1 year
  sources = [
    "source.amazon-ebs.onepassword_connect"
  ]


  provisioner "shell" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install jq"
    ]
  }


  provisioner "shell" {
    inline = [
      "echo Installing Docker...",
      "sudo yum -y install docker",
      "sudo usermod -a -G docker ec2-user",
      "id ec2-user",
      "newgrp docker",
      "sudo systemctl enable docker.service",
      "echo Rebooting...",
      "sudo reboot now"
    ]
    expect_disconnect = true
  }

  provisioner "shell" {
    pause_before     = "30s"
    environment_vars = [
      "DOCKERHUB_USER=${var.dockerhub_user}",
      "DOCKERHUB_PAT=${var.dockerhub_pat}"
    ]
    inline = [
      "echo Verifying docker is running...",
      "sudo systemctl status docker.service",

      "echo Authenticating to dockerhub with user \"$DOCKERHUB_USER\"...",
      "(echo $DOCKERHUB_PAT | docker login docker.io --username $DOCKERHUB_USER --password-stdin) || true"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Installing Docker-compose...",
      "sudo yum install -y python3-pip",
      "echo \"export PATH=\\\"/home/ec2-user/.local/bin:$PATH\\\"\" >> .bashrc",
      "source /home/ec2-user/.bashrc",
      "pip3 install --user wheel",
      "pip3 install --user docker-compose",
      "echo Rebooting...",
      "sudo reboot now"
    ]
    expect_disconnect = true
  }

  provisioner "shell" {
    pause_before = "30s"
    inline       = [
      "echo Installing onepassword-connect",
      "mkdir -p /home/ec2-user/onepassword-connect"
    ]
  }

  provisioner "file" {
    source      = "packer/docker-compose.yaml"
    destination = "/home/ec2-user/onepassword-connect/docker-compose.yaml"
  }

  provisioner "shell" {
    inline = [
      "cd /home/ec2-user/onepassword-connect",
      "docker-compose pull"
    ]
  }

  provisioner "file" {
    content = templatefile("./start-onepassword-connect.sh", {
      ONEPASSWORD_SECRET_ID = var.onepassword_secret_id
    })
    destination = "/home/ec2-user/start-onepassword-connect.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /home/ec2-user/start-onepassword-connect.sh",
      "rm -f /home/ec2-user/.docker/config.json"
    ]
  }
}


