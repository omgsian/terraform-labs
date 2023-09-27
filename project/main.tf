
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

variable "ssh_port" {
  description = "the port ssh connection is made to"
  type        = number
  default     = 22
}

variable "web_server_port" {
  description = "the port http traffic is sent to"
  type        = number
  default     = 80
}

variable "web_secure_server_port" {
  description = "the port https traffic is sent to"
  type        = number
  default     = 443
}

resource "aws_vpc" "demo_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name : "Prod_VPC"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.demo_vpc.id
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod-RT"
  }

  #   route {
  #     ipv6_cidr_block = "::/0"
  #     gateway_id      = aws_internet_gateway.gw.id
  #   }

}

resource "aws_subnet" "demo_subnet" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod_subnet"
  }

}

resource "aws_route_table_association" "route_table_asso" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = var.web_secure_server_port
    to_port     = var.web_secure_server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = var.web_server_port
    to_port     = var.web_server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTPS ipv6"
    from_port        = var.web_secure_server_port
    to_port          = var.web_secure_server_port
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP ipv6"
    from_port        = var.web_server_port
    to_port          = var.web_server_port
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "SSH"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# resource "aws_network_interface" "webserver-nic" {
#   subnet_id       = aws_subnet.demo_subnet.id
#   private_ips     = ["10.0.1.50"]
#   security_groups = [aws_security_group.allow_web.id]
# }

# resource "aws_eip" "one" {
#   domain                    = "vpc"
#   network_interface         = aws_network_interface.web-server-nic.id
#   associate_with_private_ip = "10.0.1.50"
#   depends_on                = [aws_internet_gateway.gw]
# }

# create a network interface with private ip from step 4
resource "aws_network_interface" "terra_net_interface" {
  subnet_id       = aws_subnet.demo_subnet.id
  security_groups = [aws_security_group.allow_web.id]

  tags = {
    Name = "prod_nic"
  }
}
# assign a elastic ip to the network interface created in step 7
resource "aws_eip" "terra_eip" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.terra_net_interface.id
  associate_with_private_ip = aws_network_interface.terra_net_interface.private_ip
  depends_on                = [aws_internet_gateway.gw, aws_instance.webserver]
}

resource "aws_instance" "webserver" {
  ami               = "ami-053b0d53c279acc90"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "mrh-aws"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.terra_net_interface.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt -y update 
              sudo apt -y install apache2 
              sudo systemctl start apache2
              sudo bash -c 'echo My First Web Server > /var/www/html/index.html'
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "web-server"
  }
}

# resource "aws_launch_configuration" "as_conf" {
#   image_id        = "ami-053b0d53c279acc90"
#   instance_type   = "t2.micro"
#   security_groups = [aws_security_group.allow_web.id]

#   user_data = <<-EOF
#               #!/bin/bash
#               sudo apt -y update 
#               sudo apt -y install apache2 
#               sudo systemctl start apache2
#               sudo bash -c 'echo My First Web Server > /var/www/html/index.html'
#               EOF

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_autoscaling_group" "as_group" {
#   launch_configuration = aws_launch_configuration.as_conf.name_prefix
#   min_size             = 2
#   max_size             = 5
#   tag {
#     key                 = "Name"
#     value               = "scaling group"
#     propagate_at_launch = true
#   }
# }

output "public_ip" {
  value = aws_instance.webserver.public_ip
}
