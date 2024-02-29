variable "backend_bucket_policy_name" {
  description = "Backend Bucket IAM Policy Name"
  type = string
}

variable "backend_db_policy_name" {
  description = "Backend Locks DB IAM Policy Name"
  type = string
}

variable "remote_state_bucket_name" {
  description = "Name for Bucket used for state storage."
  type = string
}

variable "bucket_key" {
  description = "State bucket key."
  type = string
  default = "global/s3/terraform.tfstate"
}

variable "dynamodb_table_name" {
  description = "DynamoDB Table Name for State Locking."
  type = string
}
