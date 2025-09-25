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

# 1. IAM Role A (ReadOnly on S3)
resource "aws_iam_role" "s3_readonly_role" {
  name = "S3ReadOnlyRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::262164343831:user/tech_eazy"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_policy" "s3_readonly_policy" {
  name   = "S3ReadOnlyPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["s3:ListBucket", "s3:GetObject"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_readonly_attach" {
  role       = aws_iam_role.s3_readonly_role.name
  policy_arn = aws_iam_policy.s3_readonly_policy.arn
}

# 2. IAM Role B (Write-only on S3, CreateBucket + PutObject)
resource "aws_iam_role" "s3_write_role" {
  name = "S3WriteOnlyRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_write_policy" {
  name   = "S3WritePolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:CreateBucket", "s3:PutObject"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_write_attach" {
  role       = aws_iam_role.s3_write_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "s3_write_instance_profile" {
  name = "S3WriteInstanceProfile"
  role = aws_iam_role.s3_write_role.name
}

# 3. Private S3 bucket
resource "aws_s3_bucket" "log_bucket" {
  bucket = var.bucket_name
  force_destroy = true

  tags = { Name = "log-bucket" }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.log_bucket.id
  acl    = "private"
}

# Lifecycle rule: delete logs after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    id     = "delete-old-logs"
    status = "Enabled"
    expiration {
      days = 7
    }
  }
}

# 4. Security group for EC2
resource "aws_security_group" "app_sg" {
  name        = "terraform-s3-app-sg"
  description = "Allow SSH + HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
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

# 5. EC2 instance
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  iam_instance_profile   = aws_iam_instance_profile.s3_write_instance_profile.name

  user_data = file("${path.module}/../Scripts/user_data.sh")

  tags = { Name = "app-with-s3-logs" }
}
