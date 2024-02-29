terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "backend" {
  source = "../../../modules/backend/s3"
  dynamodb_table_name = "terraform-up-and-running-locks"
  remote_state_bucket_name = "staging-remote-state"
  bucket_key = "global/s3/terraform.tfstate"
}
