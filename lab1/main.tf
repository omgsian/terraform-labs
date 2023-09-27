
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# resource "aws_instance" "my-first-server" {
#   ami           = "ami-053b0d53c279acc90"
#   instance_type = "t3.micro"

#   tags = {
#     # name = "ubuntu"
#   }
# }

resource "aws_vpc" "vpc-1" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name : "Production"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.vpc-1.id # referencing existing resource
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "prod-subnet"
  }
}

