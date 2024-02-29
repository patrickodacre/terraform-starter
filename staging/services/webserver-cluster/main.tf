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

# Configure Terraform to use the s3 bucket as the backend
terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket = "staging-remote-state"
    key = "global/s3/terraform.tfstate"
    region = "eu-central-1"
    # Replace this with your DynamoDB table name!
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt = true
  }
}

module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"
  # AWS will create a keypair for the EC2 instances
  ssh_keypair_name_app = "MyKeyPair"
  ssh_keypair_name_api = "MyKeyPair"
}
