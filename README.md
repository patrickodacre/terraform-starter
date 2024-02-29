# Terraform Starter Project

The goal of this project is to provide a number of starter templates for using Terraform to manage your infrastructure.

The `modules` directory contains all the various reusable modules, while `staging` contains different infrastructure implementations.

## Usage

1. rename `secret.tfvars.example` to `secret.tfvars` and add your AWS access and secret keys.

2. Initialize the s3 state storage by running `terraform init` and `terraform apply -var-file="../../secret.tfvars"` in the appropriate environment directory, e.g.: `/staging/backend/s3`.
