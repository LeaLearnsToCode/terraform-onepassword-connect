resource "aws_vpc" "main" {
  cidr_block       = local.vpc_cidr
  instance_tenancy = "default"
  tags             = {
    Name = "${var.app_env}-onepassword-connect-vpc"
  }
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
  tags   = {
    Name = "${var.app_env}-onepassword-connect-gateway"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_cidr
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name = "${var.app_env}-onepassword-public"
  }
}

resource "aws_eip" "ip" {
  vpc = true
}

resource "aws_nat_gateway" "public_nat" {
  depends_on = [
    aws_internet_gateway.gateway
  ]

  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.ip.id
  tags          = {
    Name = "${var.app_env}-onepassword-nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = {
    Name = "${var.app_env}-onepassword-public"
  }
}

resource "aws_route" "internet_gateway" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.gateway.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_route_assoc" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_cidr
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name = "${var.app_env}-onepassword-private"
  }
}

resource "aws_route" "nat_gateway" {
  route_table_id         = aws_vpc.main.main_route_table_id
  nat_gateway_id         = aws_nat_gateway.public_nat.id
  destination_cidr_block = "0.0.0.0/0"
}
