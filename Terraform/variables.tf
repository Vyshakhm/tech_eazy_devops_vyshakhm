variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name (create in AWS Console if you don't have one)"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for logs (must be unique globally)"
  type        = string
}
