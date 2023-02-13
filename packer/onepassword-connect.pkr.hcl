packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

##
## SSM agent verification keys
## from: https://docs.aws.amazon.com/systems-manager/latest/userguide/verify-agent-signature.html
##
variable "aws_ssm_agent_public_key" {
  type = string
}

variable "aws_ssm_agent_fingerprint" {
  type = string
}

##
## Rate limit tokens
##
variable "dockerhub_user" {
  type      = string
}

variable "dockerhub_pat" {
  type      = string
  sensitive = true
}

##
## AWS tags
##
variable "app_env" {
  type = string
}

variable "promoted" {
  type    = bool
  default = false
}

variable "git_sha" {
  type = string
}

variable "git_branch" {
  type = string
}

variable "git_repo" {
  type = string
}

variable "git_commit" {
  type = string
}

variable "git_tag" {
  type = string
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "amzn2" {
  ami_name             = "onepassword-connect-${local.timestamp}"
  instance_type        = "t3.micro"
  region               = "us-west-2"
  ssh_username         = "ec2-user"

  tag {
    key   = "created-with"
    value = "automation"
  }

  tag {
    key   = "app-env"
    value = var.app_env
  }

  tag {
    key   = "promoted"
    value = var.promoted
  }

  tag {
    key   = "git-sha"
    value = var.git_sha
  }

  tag {
    key   = "git-branch"
    value = var.git_branch
  }

  tag {
    key   = "git-repo"
    value = var.git_repo
  }

  tag {
    key   = "git-commit"
    value = var.git_commit
  }

  tag {
    key   = "git-tag"
    value = var.git_tag
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
      "sudo yum -y install awscli jq",
    ]
  }

  provisioner "file" {
    content     = var.aws_ssm_agent_public_key
    destination = "aws-ssm-agent.gpg"
  }

  provisioner "shell" {
    environment_vars = [
      "AWS_SSM_AGENT_FINGERPRINT=${var.aws_ssm_agent_fingerprint}"
    ]
    inline = [
      "echo Installing AWS SSM Agent...",
      "sudo gpg --import aws-ssm-agent.gpg",
      "sudo gpg --fingerprint $AWS_SSM_AGENT_FINGERPRINT",
      "curl -o amazon-ssm-agent.rpm https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm",
      "curl -o amazon-ssm-agent.rpm.sig https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm.sig",
      "sudo gpg --verify amazon-ssm-agent.rpm.sig amazon-ssm-agent.rpm",
      "sudo yum install -y amazon-ssm-agent.rpm",
      "sudo systemctl status amazon-ssm-agent",
      "rm amazon-ssm-agent.rpm.sig",
      "rm amazon-ssm-agent.rpm",
      "rm aws-ssm-agent.gpg",
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
    pause_before = "30s"
    inline = [
      "echo Installing Docker-compose...",
      "sudo yum install -y python3-pip",
      "echo \"export PATH=\\\"/home/ec2-user/.local/bin:$PATH\\\"\" >> .bashrc",
      "source /home/ec2-user/.bashrc",
      "pip3 install --user wheel",
      "pip3 install --user docker-compose",
    ]
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
      "echo Authenticating to dockerhub with user \"$DOCKERHUB_USER\"...",
      "echo $DOCKERHUB_PAT | docker login docker.io --username $DOCKERHUB_USER --password-stdin",
      "cd /home/ec2-user/onepassword-connect",
      "docker-compose pull",
      "rm -f /home/ec2-user/.docker/config.json"
    ]
  }

  provisioner "file" {
    source = "packer/start-onepassword-connect.sh"
    destination = "/home/ec2-user/start-onepassword-connect.sh"
  }

  provisioner "file" {
    source      = "packer/onepassword-connect.service"
    destination = "/home/ec2-user/onepassword-connect.service"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /home/ec2-user/start-onepassword-connect.sh",
      "sudo mv /home/ec2-user/onepassword-connect.service /etc/systemd/system/onepassword-connect.service",
      "sudo chown root:root /etc/systemd/system/onepassword-connect.service",
      "sudo systemctl enable onepassword-connect",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo yum clean all",
      "sudo rm -rf /var/cache/yum",
      "sudo yum list installed",
      "pip3 freeze",
      "sudo reboot now"
    ]
    expect_disconnect = true
  }

  provisioner "shell" {
    inline = [
      "echo All done!"
    ]
  }
}
