##############################################
# POLICIES
##############################################

# Policy for User running terraform / ansible scripts
resource "aws_iam_policy" "ansible_ssm_policy" {
  name        = "AnsibleSSMPolicy"
  description = "Policy for Ansible to interact with AWS SSM"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Role for instances to be managed BY SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name = "EC2SSMRole"

  # what types of services, etc. can use this (assume) this role?
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          # only ec2 instances can assume this role
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "EC2SSMRole"
  }
}

# Allow ec2 instances to be managed by SSM
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach this profile to any EC2 instance you wish
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "EC2SSMInstanceProfile"
  role = aws_iam_role.ec2_ssm_role.name
}

##############################################
# USERS
##############################################

# Create a new admin user
resource "aws_iam_user" "xerodone" {
  name = "xerodone"
}

resource "aws_iam_user_login_profile" "xerodone" {
  user    = aws_iam_user.xerodone.name
  password_reset_required = true
}

# Ensure our terraform User can use this
resource "aws_iam_user_policy_attachment" "ansible_user_ssm_attachment" {
  user       = "terraform"
  policy_arn = aws_iam_policy.ansible_ssm_policy.arn
}

output "password" {
  value = aws_iam_user_login_profile.xerodone.password
}

resource "aws_iam_group" "admin_group" {
  name = "Admins"
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
    Name = "DarkVPC"
  }
}

##############################################
# PUBLIC SUBNET
##############################################

resource "aws_subnet" "dvpc_public_subnet" {
  vpc_id            = aws_vpc.dark_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  map_public_ip_on_launch =  true

  tags = {
    Name = "DarkVPCPublicSubnet"
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
    Name = "DarkVPCInternetGateway"
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
    Name = "DarkVPCPublicRouteTable"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.dvpc_public_subnet.id
  route_table_id = aws_route_table.dvpc_public_route_table.id
}

##############################################
# PRIVATE SUBNET
##############################################

resource "aws_subnet" "dvpc_private_subnet" {
  vpc_id            = aws_vpc.dark_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "DarkVPCPrivateSubnet"
  }
}

# NAT Gateway, requires an Elastic IP (EIP) because it acts on
# behalf of instances in the private subnet to initiate requests
# to the internet. The EIP is associated with the NAT Gateway to
# provide it with a stable, internet-facing IP address.
# When instances in the private subnet make outbound requests,
# the NAT Gateway translates their private IP addresses to the
# NAT Gateway's EIP, allowing internet resources to send the response
# back to the NAT Gateway, which then routes the responses back to
# the correct instance in the private subnet.
resource "aws_eip" "dvpc_nat_eip" {
  # Put directly on instance? NO. We're putting it on a NAT gateway
  # instance =  aws_instance.app.id
  domain = "vpc"
}

# The nat gateway must be placed in the PUBLIC subnet so it may
# allow instances in the private subnet to initiate outbound
# connections and receive the responses to those connections.
resource "aws_nat_gateway" "dvpc_ngw" {
  allocation_id = aws_eip.dvpc_nat_eip.id
  subnet_id     = aws_subnet.dvpc_public_subnet.id
  depends_on    = [aws_internet_gateway.dvpc_igw]
  tags = {
    Name = "DarkVPCNatGateway"
  }
}

# Route table + association
resource "aws_route_table" "dvpc_private_route_table" {
  vpc_id = aws_vpc.dark_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dvpc_ngw.id
  }

  tags = {
    Name = "DarkVPCPrivateRouteTable"
  }
}
resource "aws_route_table_association" "private_a" {
  subnet_id = aws_subnet.dvpc_private_subnet.id
  route_table_id = aws_route_table.dvpc_private_route_table.id
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
    Name = "DarkVPCAPP"
  }
}

output "app_server_ip" {
  value = aws_instance.app.public_ip
}

resource "aws_instance" "api" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.dvpc_private_subnet.id
  associate_public_ip_address = false
  key_name = var.ssh_keypair_name_api

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  vpc_security_group_ids = [
    # aws_security_group.allow_ssh.id,
    # aws_security_group.allow_http.id,
  ]

  tags = {
    Name = "DarkVPCAPI"
  }
}

output "api_instance_id" {
  value = aws_instance.api.id
}