
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
    from_port   = var.server_ports[2].port
    to_port     = var.server_ports[2].port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = var.server_ports[1].port
    to_port     = var.server_ports[1].port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTPS ipv6"
    from_port        = var.server_ports[2].port
    to_port          = var.server_ports[2].port
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP ipv6"
    from_port        = var.server_ports[1].port
    to_port          = var.server_ports[1].port
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "SSH"
    from_port   = var.server_ports[0].port
    to_port     = var.server_ports[0].port
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
  ami               = var.linux-ami
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

output "public_ip" {
  value = aws_instance.webserver.public_ip
}
