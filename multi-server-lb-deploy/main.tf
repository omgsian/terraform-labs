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
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod_rt"
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
  domain     = "vpc"
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

# Configure load balancer
resource "aws_lb" "prod_lb" {
  name               = "demo-lb"
  internal           = false # assign it a public ip
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.prod_subnet1.id, aws_subnet.prod_subnet2.id]
  depends_on         = [aws_internet_gateway.gw]

  tags = {
    Name = "prod_lb"
  }
}

resource "aws_lb_target_group" "prod_lb_tg" {
  name     = "load-balancer-tg"
  port     = var.server_ports[1].port
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id

  tags = {
    Name = "prod_lb"
  }
}

resource "aws_lb_listener" "prod_lb_listener" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port              = var.server_ports[1].port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_lb_tg.arn
  }

  tags = {
    Name = "prod_lb"
  }
}

resource "aws_security_group" "lb_sg" {
  name   = "load balancer security group"
  vpc_id = aws_vpc.default.id

  ingress {
    description      = "Allow http request from anywhere"
    protocol         = "tcp"
    from_port        = var.server_ports[1].port
    to_port          = var.server_ports[1].port
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow https request from anywhere"
    protocol         = "tcp"
    from_port        = var.server_ports[2].port
    to_port          = var.server_ports[2].port
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow ssh connection from anywhere"
    protocol         = "tcp"
    from_port        = var.server_ports[0].port
    to_port          = var.server_ports[0].port
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Create EC2 using AWS lauch template with ASG enabled

resource "aws_launch_template" "prod_lt" {
  name_prefix   = "prod_ec2_lt"
  image_id      = var.linux-ami
  instance_type = "t2.micro"
  user_data     = filebase64("server_cmds.sh")
  key_name      = "mrh-aws"

  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = aws_subnet.prod_subnet2.id
    security_groups             = [aws_security_group.ec2_sg.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ec2_instance" # Name for the EC2 instances
    }
  }
}

resource "aws_autoscaling_group" "prod_asg" {
  # no of instances
  desired_capacity = 2
  min_size         = 2
  max_size         = 4

  # Connect to the target group
  target_group_arns = [aws_lb_target_group.prod_lb_tg.arn]

  vpc_zone_identifier = [
    aws_subnet.prod_subnet2.id # Creating EC2 instances in private subnet
  ]

  launch_template {
    id      = aws_launch_template.prod_lt.id
    version = "$Latest"
  }
}

resource "aws_security_group" "ec2_sg" {
  name   = "ec2 security group"
  vpc_id = aws_vpc.default.id

  ingress {
    description     = "Allow http request from Load Balancer"
    protocol        = "tcp"
    from_port       = var.server_ports[1].port # range of
    to_port         = var.server_ports[1].port # port numbers
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    description     = "Allow ssh connections"
    protocol        = "tcp"
    from_port       = var.server_ports[0].port # range of
    to_port         = var.server_ports[0].port # port numbers
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


output "alb_dns_name" {
  value       = aws_lb.prod_lb.dns_name
  description = "The domain name of the load balancer"
}
