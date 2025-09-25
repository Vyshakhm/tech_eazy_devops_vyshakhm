output "public_ip" {
  value = aws_instance.app.public_ip
}

output "bucket_name" {
  value = aws_s3_bucket.log_bucket.bucket
}
