resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/23" # 512 IPs 
  tags = {
    Name = "prod_vpc"
  }
}

# Public subnet
resource "aws_subnet" "prod_subnet1" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.0.0/27" #32 IPs
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

# Public subnet
resource "aws_subnet" "prod_subnet2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.0.32/27" #32 IPs
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
}

# Private subnet 
resource "aws_subnet" "prod_subnet3" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/27" #32 IPs
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
}

# Internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.default.id
  tags = {
    Name : "prod_gw"
  }
}

# Route traffic for public subnets
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = ["0.0.0.0/0"]
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name : prod_rt
  }
}

# Create the route to public subnet 1
resource "aws_route_table_association" "rta_1" {
  subnet_id      = aws_subnet.prod_subnet1.id
  route_table_id = aws_route_table.rt.id
}

# Create the route to public subnet 2
resource "aws_route_table_association" "rta_2" {
  subnet_id      = aws_subnet.prod_subnet2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_eip" "eip" {
  depends_on = [aws_internet_gateway.gw]
  vpc        = true
  tags = {
    Name = "prod_eip"
  }
}

resource "aws_nat_gateway" "private_subnet_gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.prod_subnet1.id

  tags = {
    Name = "Private subnet NAT gateway"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private_subnet_gw.id
  }
}

# Create the route to private subnet 3
resource "aws_route_table_association" "rta_3" {
  subnet_id      = aws_subnet.prod_subnet3.id
  route_table_id = aws_route_table.rt_private.id
}
