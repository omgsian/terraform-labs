data "aws_vpc" "default" {
  cidr_block = "10.0.0.0/23" # 512 IPs 
  tags = {
    Name = "prod_vpc"
  }
}

# Public subnet
data "aws_subnet" "prod_subnet1" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.0.0/27" #32 IPs
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

# Public subnet
data "aws_subnet" "prod_subnet2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.0.32/27" #32 IPs
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
}

# Private subnet 
data "aws_subnet" "prod_subnet2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/27" #32 IPs
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
}


