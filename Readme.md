# Deploy Trainigs-TechEazy Java App on Ubuntu EC2 using Terraform


## Prerequisites (on your local machine)
1. Terraform installed (>= 1.5 recommended)
2. AWS CLI installed and configured with credentials:
3. An EC2 Key Pair created in AWS Console (e.g., `my-key`). Download the `.pem` file to your machine.
4. Git (optional; we use Git on the instance, not locally).
5. IAM Permissions: The user running Terraform must have permissions to create EC2 instances, IAM Roles/Policies, and S3 Buckets.


# Initialize the project and download providers
terraform init

# Review the execution plan
terraform plan

# Apply the changes and deploy the infrastructure
terraform apply

