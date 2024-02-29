variable "user_name" {
  description = "Name of New Admin User"
  type = string
}

variable "unique_admin_group_name" {
  description = "Unique name for the admin group"
  type = string
}

variable "vpc_prefix" {
  description = "Unique prefix for VPC"
  type = string
}

variable "az" {
  description = "Availability Zone"
  type = string
}

variable "ssh_keypair_name_app" {
  description = "Name of the SSH Key Pair created using the AWS CLI"
  type = string
}
