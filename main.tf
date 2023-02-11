
variable "onepassword_server_profile_id" {
  type = string
  description = "IAM instance profile id"
}

data "aws_ami" "onepassword_ami" {
  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["onepassword-connect-*"]
  }

  filter {
    name   = "tag:created-with"
    values = ["automation"]
  }
}

data "aws_iam_instance_profile" "onepassword" {
  name = var.onepassword_server_profile_id
}

resource "aws_instance" "instance" {
  ami           = data.aws_ami.onepassword_ami.id
  instance_type = "t2.micro"
  iam_instance_profile = data.aws_iam_instance_profile.onepassword.name
}
