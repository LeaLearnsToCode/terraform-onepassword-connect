resource "aws_vpc" "main" {
  cidr_block       = local.vpc_cidr
  instance_tenancy = "default"
  tags             = {
    Name = "${var.app_env}-vpc"
  }
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_s3_bucket" "rejected_flow_log" {
  bucket = "${var.app_env}-vpc-rejected-flow-log"
}

resource "aws_s3_bucket_acl" "rejected_flow_log" {
  bucket = aws_s3_bucket.rejected_flow_log.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "rejected_flow_log" {
  bucket = aws_s3_bucket.rejected_flow_log.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encrypt" {
  bucket = aws_s3_bucket.rejected_flow_log.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.secret.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_flow_log" "rejected_traffic_flow_log" {
  log_destination      = aws_s3_bucket.rejected_flow_log.arn
  log_destination_type = "s3"
  traffic_type         = "REJECT"
  vpc_id               = aws_vpc.main.id
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
  tags   = {
    Name = "${var.app_env}-gateway"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_cidr
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name = "${var.app_env}-public-subnet"
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
    Name = "${var.app_env}-nat-gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = {
    Name = "${var.app_env}-public-routes"
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
    Name = "${var.app_env}-private-subnet"
  }
}

resource "aws_route" "nat_gateway" {
  route_table_id         = aws_vpc.main.main_route_table_id
  nat_gateway_id         = aws_nat_gateway.public_nat.id
  destination_cidr_block = "0.0.0.0/0"
}
