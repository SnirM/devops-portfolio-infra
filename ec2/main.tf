terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# -------------------------
# Network (Default VPC/Subnet for simplicity)
# -------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  subnet_id = data.aws_subnets.default_vpc_subnets.ids[0]
}

# -------------------------
# Security Group: 22 + 80 inbound, all outbound
# -------------------------
resource "aws_security_group" "app_sg" {
  name        = "devops-portfolio-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-portfolio-sg"
  }
}

# -------------------------
# IAM Role for EC2: ECR pull + SSM
# -------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "devops-portfolio-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devops-portfolio-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# -------------------------
# EC2 Instance
# -------------------------
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type           = var.instance_type
  subnet_id               = local.subnet_id
  vpc_security_group_ids  = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # Optional: if you created a Key Pair in AWS, put its name in terraform.tfvars.
  key_name = var.key_name != "" ? var.key_name : null

  user_data = <<-EOF
    #!/bin/bash
    set -e

    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

    echo "=== Updating OS ==="
    yum update -y

    echo "=== Installing docker ==="
    amazon-linux-extras install docker -y || yum install -y docker

    echo "=== Starting docker ==="
    service docker start || systemctl start docker
    systemctl enable docker || true

    echo "=== Installing AWS CLI (if missing) ==="
    command -v aws >/dev/null 2>&1 || yum install -y awscli

    echo "=== Login to ECR ==="
    aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.ecr_registry}

    echo "=== Pulling image ==="
    docker pull ${var.ecr_repo}:latest

    echo "=== Running container on port 80 -> 8000 ==="
    docker rm -f devops-portfolio-app || true
    docker run -d --restart=always --name devops-portfolio-app -p 80:8000 ${var.ecr_repo}:latest

    echo "=== Done ==="
  EOF

  tags = {
    Name = "devops-portfolio-ec2"
  }
}
