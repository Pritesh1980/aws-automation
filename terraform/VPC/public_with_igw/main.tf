provider "aws" {
  profile    = var.aws_profile 
  region = var.region
}


resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true
  
  tags = {
    Name = "TF-VPC-Public"
  }
}

# Subnet A ###########################
resource "aws_subnet" "public_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  # availability_zone = "eu-west-1a"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-A"
  }
}


# Subnet B ###########################
resource "aws_subnet" "public_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-B"
  }
}


# Subnet C ###########################
resource "aws_subnet" "public_c" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.5.0/24"
  availability_zone = "${var.region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-C"
  }
}



# IGW for public subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "TF-IGW"
  }
}


# Public routing table, adding IGW to all public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "TF-Public-RT"
  }
}

resource "aws_route" "public_r" {
  route_table_id            = aws_route_table.public_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.gw.id 
  depends_on                = [aws_route_table.public_rt]
}

resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "pub_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public_rt.id
}

