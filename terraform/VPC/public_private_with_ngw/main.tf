provider "aws" {
  profile = var.aws_profile 
  region = var.region
}


resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "TF-VPC"
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

resource "aws_subnet" "private_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private-A"
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

resource "aws_subnet" "private_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private-B"
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

resource "aws_subnet" "private_c" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.6.0/24"
  availability_zone = "${var.region}c"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private-C"
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

# Private routing table, adding NAT gateway to all private subnets
resource "aws_eip" "nat" {
  vpc                       = true
  depends_on                = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id  # ideally use one nat gateway per AZ. Using just one here to keep costs manageable

  tags = {
    Name = "TF NAT gw"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "TF-Private-RT"
  }
}

resource "aws_route" "private_r" {
  route_table_id            = aws_route_table.private_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = aws_nat_gateway.gw.id 
  depends_on                = [aws_route_table.private_rt]
}

resource "aws_route_table_association" "pri_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "pri_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "pri_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_rt.id
}