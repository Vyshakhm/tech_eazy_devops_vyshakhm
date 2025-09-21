terraform {
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

# Get latest Ubuntu 22.04 (Jammy) AMI provided by Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group allowing SSH (22) and HTTP (80)
resource "aws_security_group" "app_sg" {
  name        = "terraform-ubuntu-app-sg"
  description = "Allow SSH and HTTP to the app"

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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance - Ubuntu
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Run bootstrap script (installs Java/Maven/git + clones/builds + creates systemd)
  user_data = file("${path.module}/../Scripts/user_data.sh")

  tags = {
    Name = "terraform-ubuntu-app"
  }

  # Wait for SSH to be available before finishing apply (optional: helpful if you later add remote provisioners)
  provisioner "local-exec" {
    command = "echo 'Instance ${self.id} created with public IP ${self.public_ip}'"
  }
}
