variable "ssh_keypair_name_app" {
  description = "Name of the SSH Key Pair created using the AWS CLI"
  type = string
}

variable "ssh_keypair_name_api" {
  description = "Name of the SSH Key Pair created for the API server"
  type = string
}