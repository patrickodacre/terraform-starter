# Terraform Stater Project

## Usage

1. rename `secret.tfvars.example` to `secret.tfvars` and add your AWS access and secret keys.

2. Initialize the s3 state storage by running `terraform init` and `terraform apply -var-file="../../secret.tfvars"` in the appropriate environment directory, e.g.: `/staging/backend/s3`.