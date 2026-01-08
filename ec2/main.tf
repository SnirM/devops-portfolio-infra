provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "app_sg" {
  name        = "devops-portfolio-sg"
  description = "Allow HTTP"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  security_groups = [aws_security_group.app_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user

    aws ecr get-login-password --region ap-south-1 \
    | docker login --username AWS --password-stdin ${var.ecr_repo}

    docker run -d -p 80:8000 ${var.ecr_repo}:latest
  EOF

  tags = {
    Name = "devops-portfolio-ec2"
  }
}

