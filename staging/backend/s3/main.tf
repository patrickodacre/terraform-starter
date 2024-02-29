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
  backend_bucket_policy_name = "TerraformS3BackendAccess"
  backend_db_policy_name = "TerraformS3BackendAccessDB"
  dynamodb_table_name = "terraform-up-and-running-locks"
  remote_state_bucket_name = "staging-remote-state"
  bucket_key = "global/s3/terraform.tfstate"
}

module "docker_backend" {
  source = "../../../modules/backend/s3"
  backend_bucket_policy_name = "TFDockerBucket"
  backend_db_policy_name = "TFDockerDB"
  dynamodb_table_name = "docker-backend-locks"
  remote_state_bucket_name = "pwho-docker-remote-state"
  bucket_key = "global/s3/terraform.tfstate"
}