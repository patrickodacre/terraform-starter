# Terraform Starter Project

The goal of this project is to provide a number of starter templates for using Terraform to manage your infrastructure.

The `modules` directory contains all the various reusable modules, while `staging` contains different infrastructure implementations.

## Usage

1. rename `secret.tfvars.example` to `secret.tfvars` and add your AWS access and secret keys.

2. Initialize the s3 state storage by running `terraform init` and `terraform apply -var-file="../../secret.tfvars"` in the appropriate environment directory, e.g.: `/staging/backend/s3`.


## Guides

* create a key pair on AWS using the AWS cli `aws ec2 create-key-pair --key-name [name] --query 'KeyMaterial' --output text > ~/.ssh/[name].pem` && `chmod 400 ~/.ssh/[name].pem`

* ssh into your newly created ec2 instance `ssh -i ~/.ssh/[name].pem ec2-user@[instance ip]`

