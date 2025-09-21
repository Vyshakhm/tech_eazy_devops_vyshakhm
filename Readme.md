# Deploy Trainigs-TechEazy Java App on Ubuntu EC2 using Terraform

This guide provisions an Ubuntu EC2 instance, installs Java/Maven, builds the GitHub project,
and runs it as a systemd service on port 80. Terraform manages the VM.

## Prerequisites (on your local machine)
1. Terraform installed (>= 1.5 recommended)
2. AWS CLI installed and configured with credentials:
3. An EC2 Key Pair created in AWS Console (e.g., `my-key`). Download the `.pem` file to your machine.
4. Git (optional; we use Git on the instance, not locally).

## Repo layout (local)
