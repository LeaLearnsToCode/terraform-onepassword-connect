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
  sensitive = true
}

variable "onepassword_server_profile_id" {
  type      = string
  sensitive = true
}

variable "source_repo" {
  type = string
}

variable "commit_hash" {
  type = string
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "amzn2" {
  ami_name             = "onepassword-connect-${local.timestamp}"
  instance_type        = "t3.micro"
  region               = "us-west-2"
  iam_instance_profile = var.onepassword_server_profile_id
  ssh_username         = "ec2-user"

  tag {
    key  = "created-with"
    value = "automation"
  }

  tag {
    key  = "source-repo"
    value = var.source_repo
  }

  tag {
    key   = "commit-hash"
    value = var.commit_hash
  }

  source_ami_filter {
    filters = {
      name                = "amzn2-ami-minimal-hvm-*"
      #name                = "amzn2-ami-hvm-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["137112412989"]
  }
}

build {
  name    = "onepassword-connect"
  #deprecate_at = timeadd(timestamp(), "525600m") # 1 year
  sources = [
    "source.amazon-ebs.amzn2"
  ]

  provisioner "shell" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install awscli jq"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Installing Docker...",
      "sudo amazon-linux-extras install docker",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo Verifying docker is running...",
      "sudo journalctl -u docker -e",
      "sudo systemctl status docker",
      "sudo usermod -aG docker $USER",
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
      "echo Checking docker after reboot",
      "docker info",
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

  provisioner "file" {
    source      = "packer/onepassword-connect.service"
    destination = "/home/ec2-user/onepassword-connect.service"
  }

  provisioner "shell" {
    environment_vars = [
      "ONEPASSWORD_SECRET_ID=${var.onepassword_secret_id}",
      "ONEPASSWORD_SECRET_PATH=/home/ec2-user/onepassword-connect/1password-credentials.json",
    ]
    inline = [
      "chmod +x /home/ec2-user/start-onepassword-connect.sh",
      "sudo mv /home/ec2-user/onepassword-connect.service /etc/systemd/system/onepassword-connect.service",
      "sudo chown root:root /etc/systemd/system/onepassword-connect.service",
      "sudo systemctl enable onepassword-connect",
      "echo Rebooting...",
      "sudo reboot now"
    ]
    expect_disconnect = true
  }

  provisioner "shell" {
    pause_before = "30s"
    inline       = [
      "echo Checking that onepassword-connect is running...",
      "sudo journalctl -u onepassword-connect -e",
      "sudo systemctl status onepassword-connect",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo yum clean all",
      "sudo rm -rf /var/cache/yum",
      "sudo yum list installed",
      "pip3 freeze"
    ]
  }

  provisioner "shell" {
    inline = [
      "rm -f /home/ec2-user/onepassword-connect/1password-credentials.json",
      "rm -f /home/ec2-user/.docker/config.json"
    ]
  }
}
