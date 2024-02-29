##############################################
# USERS
##############################################

# Create a new admin user
resource "aws_iam_user" "xerodone" {
  name = var.user_name
}

resource "aws_iam_user_login_profile" "xerodone" {
  user    = aws_iam_user.xerodone.name
  password_reset_required = true
}

resource "aws_iam_group" "admin_group" {
  name = var.unique_admin_group_name
}

resource "aws_iam_user_group_membership" "user_to_admin_group" {
  user = aws_iam_user.xerodone.name

  groups = [
    aws_iam_group.admin_group.name,
  ]
}

resource "aws_iam_group_policy_attachment" "admin_attach" {
  group      = aws_iam_group.admin_group.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create VPC
resource "aws_vpc" "dark_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_prefix
  }
}

##############################################
# PUBLIC SUBNET
##############################################

resource "aws_subnet" "dvpc_public_subnet" {
  vpc_id            = aws_vpc.dark_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az
  map_public_ip_on_launch =  true

  tags = {
    Name = "${var.vpc_prefix}PublicSubnet"
  }
}

# Attach Internet Gateway to VPC
# Not used for responses going back to the private subnet.
# Internet GW allows requests coming in from the Internet
# to the public subnet.
# The IGW is needed to route traffic to and from any EIP
# in the VPC, e.g.: to an EIP attached to an EC2 instance
# running a app server.
resource "aws_internet_gateway" "dvpc_igw" {
  vpc_id = aws_vpc.dark_vpc.id
  tags = {
    Name = "${var.vpc_prefix}InternetGateway"
  }
}

# Route Table + association
resource "aws_route_table" "dvpc_public_route_table" {
  vpc_id = aws_vpc.dark_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # all traffic
    gateway_id = aws_internet_gateway.dvpc_igw.id # should go to this gateway
  }

  tags = {
    Name = "${var.vpc_prefix}PublicRouteTable"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.dvpc_public_subnet.id
  route_table_id = aws_route_table.dvpc_public_route_table.id
}

##############################################
# SECURITY GROUPS
##############################################
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.dark_vpc.id

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ingress" {
  security_group_id = aws_security_group.allow_ssh.id
  # cidr_ipv4         = aws_vpc.dark_vpc.cidr_block
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_ssh_egress" {
  security_group_id = aws_security_group.allow_ssh.id
  # cidr_ipv4         = aws_vpc.dark_vpc.cidr_block
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" // out to any port
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.dark_vpc.id

  tags = {
    Name = "allow_http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ingress" {
  security_group_id = aws_security_group.allow_http.id
  # cidr_ipv4         = aws_vpc.dark_vpc.cidr_block
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_http_egress" {
  security_group_id = aws_security_group.allow_http.id
  # cidr_ipv4         = aws_vpc.dark_vpc.cidr_block
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" // out to any port
}

# Create Machine latest ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


# NIC NO! use the default ENI so our simple vpc_security_group_ids works
# resource "aws_network_interface" "dvpc_public_nic" {
#   subnet_id   = aws_subnet.dvpc_public_subnet.id
#   private_ips = ["10.0.1.100"]

#   tags = {
#     Name = "PrimaryNetworkInterface"
#   }
# }

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.dvpc_public_subnet.id
  associate_public_ip_address = true
  key_name = var.ssh_keypair_name_app

  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.allow_http.id,
  ]

  tags = {
    Name = "${var.vpc_prefix}PublicInstance"
  }
}
