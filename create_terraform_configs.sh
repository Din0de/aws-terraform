#!/usr/bin/env bash
#
# create_terraform_configs.sh
#
# This script will prompt for Terraform resource details matching
# your example main.tf. It captures all fields (including from_port,
# to_port, ip_protocol) so nothing is missed from your original file.
#
# It generates:
#   - backend.tf
#   - provider.tf
#   - main.tf
#   - userdata.sh (optionally)
# in your home directory (~).
#

########################################
# 0) Helper function for yes/no
########################################

ask_yes_no() {
  local prompt="$1"
  local answer
  while true; do
    read -r -p "$prompt (y/n): " answer
    case "$answer" in
      [Yy]* ) echo "yes"; return;;
      [Nn]* ) echo "no";  return;;
      * ) echo "Please answer y or n.";;
    esac
  done
}

########################################
# 1) Gather information for backend.tf
########################################

echo "=== Configuring backend S3 settings (backend.tf) ==="
read -r -p "Enter S3 bucket name (e.g., 'tf-dk-2025'): " s3_bucket
read -r -p "Enter S3 key (e.g., 'key/tf-dk-2025'): " s3_key
read -r -p "Enter AWS region for S3 backend (e.g., 'us-east-1'): " s3_region

########################################
# 2) Gather information for provider.tf
########################################

echo "=== Configuring AWS provider (provider.tf) ==="
read -r -p "Enter AWS region for provider (e.g., 'us-east-1'): " provider_region

########################################
# 3) Collect main.tf resource creation
########################################

MAIN_CONTENT="# main.tf\n\n"

####################################################
# 3a) VPC Resource
####################################################
create_vpc=$(ask_yes_no "Do you want to create an AWS VPC resource?")
if [[ "$create_vpc" == "yes" ]]; then
  echo "=== VPC Resource ==="
  read -r -p "Enter VPC resource name (e.g., 'vpc-example'): " vpc_name
  read -r -p "Enter VPC CIDR block (e.g., '100.64.0.0/16'): " vpc_cidr
  read -r -p "Enable DNS support? (true/false): " vpc_dns_support
  read -r -p "Enable DNS hostnames? (true/false): " vpc_dns_hostnames
  read -r -p "Enter VPC tag name (e.g., 'vpc-example'): " vpc_tag

  MAIN_CONTENT+=$(cat <<EOF
# Create VPC
resource "aws_vpc" "$vpc_name" {
  cidr_block           = "$vpc_cidr"
  enable_dns_support   = "$vpc_dns_support"
  enable_dns_hostnames = "$vpc_dns_hostnames"
  tags = {
    Name = "$vpc_tag"
  }
}

EOF
)
fi

####################################################
# 3b) Internet Gateway
####################################################
create_igw=$(ask_yes_no "Do you want to create an Internet Gateway resource?")
if [[ "$create_igw" == "yes" ]]; then
  echo "=== Internet Gateway Resource ==="
  read -r -p "Enter IGW resource name (e.g., 'igw-example'): " igw_name
  echo "Hint: if your VPC resource name was 'vpc-example', reference it with aws_vpc.vpc-example.id"
  read -r -p "Enter the vpc_id reference (e.g. 'aws_vpc.vpc-example.id'): " igw_vpc_id
  read -r -p "Enter IGW tag name (e.g., 'igw-example'): " igw_tag

  MAIN_CONTENT+=$(cat <<EOF
# Create Internet Gateway
resource "aws_internet_gateway" "$igw_name" {
  vpc_id = $igw_vpc_id
  tags = {
    Name = "$igw_tag"
  }
}

EOF
)
fi

####################################################
# 3c) Public Subnet
####################################################
create_public_subnet=$(ask_yes_no "Do you want to create a Public Subnet resource?")
if [[ "$create_public_subnet" == "yes" ]]; then
  echo "=== Public Subnet Resource ==="
  read -r -p "Enter Public Subnet resource name (e.g., 'public-tf-sn'): " pub_subnet_name
  read -r -p "Enter Public Subnet CIDR block (e.g., '100.64.1.0/24'): " pub_subnet_cidr
  read -r -p "Do you want map_public_ip_on_launch set to true/false?: " pub_map_ip
  echo "Hint: if your VPC resource name was 'vpc-example', reference it with aws_vpc.vpc-example.id"
  read -r -p "Enter vpc_id reference for the Public Subnet (e.g. 'aws_vpc.vpc-example.id'): " pub_subnet_vpc
  read -r -p "Enter Availability Zone (e.g., 'us-east-1a'): " pub_subnet_az
  read -r -p "Enter Public Subnet Tag Name (e.g., 'public-tf-sn'): " pub_subnet_tag

  MAIN_CONTENT+=$(cat <<EOF
# Create the public subnet
resource "aws_subnet" "$pub_subnet_name" {
  cidr_block              = "$pub_subnet_cidr"
  map_public_ip_on_launch = "$pub_map_ip"
  vpc_id                  = $pub_subnet_vpc
  availability_zone       = "$pub_subnet_az"
  tags = {
    Name = "$pub_subnet_tag"
  }
}

EOF
)
fi

####################################################
# 3d) Private Subnet
####################################################
create_private_subnet=$(ask_yes_no "Do you want to create a Private Subnet resource?")
if [[ "$create_private_subnet" == "yes" ]]; then
  echo "=== Private Subnet Resource ==="
  read -r -p "Enter Private Subnet resource name (e.g., 'private-tf-sn'): " priv_subnet_name
  read -r -p "Enter Private Subnet CIDR block (e.g., '100.64.2.0/24'): " priv_subnet_cidr
  echo "Hint: if your VPC resource name was 'vpc-example', reference it with aws_vpc.vpc-example.id"
  read -r -p "Enter vpc_id reference for the Private Subnet (e.g., 'aws_vpc.vpc-example.id'): " priv_subnet_vpc
  read -r -p "Enter Availability Zone (e.g., 'us-east-1b'): " priv_subnet_az
  read -r -p "Enter Private Subnet Tag Name (e.g., 'private-tf-sn'): " priv_subnet_tag

  MAIN_CONTENT+=$(cat <<EOF
# Create the private subnet
resource "aws_subnet" "$priv_subnet_name" {
  cidr_block        = "$priv_subnet_cidr"
  vpc_id            = $priv_subnet_vpc
  availability_zone = "$priv_subnet_az"
  tags = {
    Name = "$priv_subnet_tag"
  }
}

EOF
)
fi

####################################################
# 3e) Route Table
####################################################
create_route_table=$(ask_yes_no "Do you want to create a Route Table resource?")
if [[ "$create_route_table" == "yes" ]]; then
  echo "=== Route Table Resource ==="
  read -r -p "Enter Route Table resource name (e.g., 'public-tf-rt'): " rt_name
  echo "Hint: if your VPC resource name is 'vpc-example', reference it with aws_vpc.vpc-example.id"
  read -r -p "Enter vpc_id reference for the Route Table (e.g., 'aws_vpc.vpc-example.id'): " rt_vpc_id
  read -r -p "Enter Route Table Tag Name (e.g., 'public-tf-RT'): " rt_tag

  MAIN_CONTENT+=$(cat <<EOF
# Create the route table
resource "aws_route_table" "$rt_name" {
  vpc_id = $rt_vpc_id
  tags = {
    Name = "$rt_tag"
  }
}

EOF
)
fi

####################################################
# 3f) Route
####################################################
create_route=$(ask_yes_no "Do you want to create a Route resource? (default route to internet, etc.)")
if [[ "$create_route" == "yes" ]]; then
  echo "=== Route Resource ==="
  read -r -p "Enter Route resource name (e.g., 'public-tf-route'): " route_name
  echo "Hint: if your Route Table resource is 'public-tf-rt', reference it with aws_route_table.public-tf-rt.id"
  read -r -p "Enter route_table_id reference (e.g., 'aws_route_table.public-tf-rt.id'): " route_table_ref
  read -r -p "Enter destination CIDR block (e.g., '0.0.0.0/0'): " destination_cidr
  echo "Hint: if your IGW resource name is 'igw-example', reference it with aws_internet_gateway.igw-example.id"
  read -r -p "Enter Internet Gateway reference for gateway_id (e.g., 'aws_internet_gateway.igw-example.id'): " route_igw_ref

  MAIN_CONTENT+=$(cat <<EOF
# Create the public route
resource "aws_route" "$route_name" {
  route_table_id         = $route_table_ref
  destination_cidr_block = "$destination_cidr"
  gateway_id             = $route_igw_ref
}

EOF
)
fi

####################################################
# 3g) Route Table Association
####################################################
create_rta=$(ask_yes_no "Do you want to associate a Subnet with a Route Table?")
if [[ "$create_rta" == "yes" ]]; then
  echo "=== Route Table Association Resource ==="
  read -r -p "Enter RT Association resource name (e.g., 'public-sn-to-public-rt'): " rta_name
  echo "Hint: if your Route Table resource is 'public-tf-rt', reference it with aws_route_table.public-tf-rt.id"
  read -r -p "Enter route_table_id reference (e.g., 'aws_route_table.public-tf-rt.id'): " rta_route_table
  echo "Hint: if your public Subnet resource is 'public-tf-sn', reference it with aws_subnet.public-tf-sn.id"
  read -r -p "Enter subnet_id reference (e.g., 'aws_subnet.public-tf-sn.id'): " rta_subnet

  MAIN_CONTENT+=$(cat <<EOF
# Associate subnet with the route table
resource "aws_route_table_association" "$rta_name" {
  route_table_id = $rta_route_table
  subnet_id      = $rta_subnet
}

EOF
)
fi

####################################################
# 3h) Security Group
####################################################
create_sg=$(ask_yes_no "Do you want to create a Security Group?")
if [[ "$create_sg" == "yes" ]]; then
  echo "=== Security Group Resource ==="
  read -r -p "Enter Security Group resource name (e.g. 'sg-tf'): " sg_name
  read -r -p "Enter Security Group name (e.g. 'allow SSH and HTTP'): " sg_display_name
  read -r -p "Enter Security Group description (e.g. 'allow SSH and HTTP'): " sg_desc
  echo "Hint: if your VPC resource is 'vpc-example', reference it with aws_vpc.vpc-example.id"
  read -r -p "Enter vpc_id reference for the Security Group (e.g., 'aws_vpc.vpc-example.id'): " sg_vpc_ref
  read -r -p "Enter Security Group Tag Name (e.g. 'sg-tf'): " sg_tag

  MAIN_CONTENT+=$(cat <<EOF
# Create the security group
resource "aws_security_group" "$sg_name" {
  name        = "$sg_display_name"
  description = "$sg_desc"
  vpc_id      = $sg_vpc_ref
  tags = {
    Name = "$sg_tag"
  }
}

EOF
)
fi

####################################################
# 3i) Ingress SSH Rule
####################################################
create_sg_ingress_ssh=$(ask_yes_no "Do you want to create an Ingress Rule for SSH?")
if [[ "$create_sg_ingress_ssh" == "yes" ]]; then
  echo "=== SSH Ingress Rule Resource ==="
  read -r -p "Enter resource name for SSH ingress (e.g., 'allow-ssh'): " sg_ingress_ssh_name
  echo "Hint: reference your SG with aws_security_group.sg-tf.id if sg-tf is the name."
  read -r -p "Enter security_group_id reference (e.g., 'aws_security_group.sg-tf.id'): " sg_ssh_ref
  read -r -p "Enter CIDR IPv4 for SSH (e.g. '0.0.0.0/0'): " sg_ssh_cidr
  read -r -p "Enter from_port for SSH (e.g., 22): " sg_ssh_from_port
  read -r -p "Enter to_port for SSH (e.g., 22): " sg_ssh_to_port
  read -r -p "Enter ip_protocol for SSH (e.g., 'tcp'): " sg_ssh_protocol

  MAIN_CONTENT+=$(cat <<EOF
# Ingress SSH rule for security group
resource "aws_vpc_security_group_ingress_rule" "$sg_ingress_ssh_name" {
  security_group_id = $sg_ssh_ref
  cidr_ipv4         = "$sg_ssh_cidr"
  from_port         = $sg_ssh_from_port
  to_port           = $sg_ssh_to_port
  ip_protocol       = "$sg_ssh_protocol"
}

EOF
)
fi

####################################################
# 3j) Ingress HTTP Rule
####################################################
create_sg_ingress_http=$(ask_yes_no "Do you want to create an Ingress Rule for HTTP?")
if [[ "$create_sg_ingress_http" == "yes" ]]; then
  echo "=== HTTP Ingress Rule Resource ==="
  read -r -p "Enter resource name for HTTP ingress (e.g., 'allow-http'): " sg_ingress_http_name
  echo "Hint: reference your SG with aws_security_group.sg-tf.id if sg-tf is the name."
  read -r -p "Enter security_group_id reference (e.g., 'aws_security_group.sg-tf.id'): " sg_ref_http
  read -r -p "Enter CIDR IPv4 for HTTP (e.g. '0.0.0.0/0'): " sg_http_cidr
  read -r -p "Enter from_port for HTTP (e.g., 80): " sg_http_from_port
  read -r -p "Enter to_port for HTTP (e.g., 80): " sg_http_to_port
  read -r -p "Enter ip_protocol for HTTP (e.g., 'tcp'): " sg_http_protocol

  MAIN_CONTENT+=$(cat <<EOF
# Ingress HTTP rule for security group
resource "aws_vpc_security_group_ingress_rule" "$sg_ingress_http_name" {
  security_group_id = $sg_ref_http
  cidr_ipv4         = "$sg_http_cidr"
  from_port         = $sg_http_from_port
  to_port           = $sg_http_to_port
  ip_protocol       = "$sg_http_protocol"
}

EOF
)
fi

####################################################
# 3k) Egress Rule (All Outbound or Another Rule)
####################################################
create_sg_egress=$(ask_yes_no "Do you want to create a Security Group Egress Rule?")
if [[ "$create_sg_egress" == "yes" ]]; then
  echo "=== Egress Rule Resource ==="
  read -r -p "Enter resource name for egress (e.g., 'all-outbound'): " sg_egress_name
  echo "Hint: reference your SG with aws_security_group.sg-tf.id if sg-tf is the name."
  read -r -p "Enter security_group_id reference (e.g., 'aws_security_group.sg-tf.id'): " sg_ref_out
  read -r -p "Enter CIDR IPv4 for Egress (e.g. '0.0.0.0/0'): " sg_egress_cidr
  read -r -p "Enter from_port for Egress (e.g., 80): " sg_egress_from_port
  read -r -p "Enter to_port for Egress (e.g., 80): " sg_egress_to_port
  read -r -p "Enter ip_protocol for Egress (e.g., '-1'): " sg_egress_protocol

  MAIN_CONTENT+=$(cat <<EOF
# Egress rule for security group
resource "aws_vpc_security_group_egress_rule" "$sg_egress_name" {
  security_group_id = $sg_ref_out
  cidr_ipv4         = "$sg_egress_cidr"
  from_port         = $sg_egress_from_port
  to_port           = $sg_egress_to_port
  ip_protocol       = "$sg_egress_protocol"
}

EOF
)
fi

####################################################
# 3l) EC2 Instance
####################################################
create_ec2=$(ask_yes_no "Do you want to create an EC2 Instance?")
if [[ "$create_ec2" == "yes" ]]; then
  echo "=== EC2 Instance Resource ==="
  read -r -p "Enter EC2 resource name (e.g. 'ec2-terraformed'): " ec2_name
  read -r -p "Enter AMI ID (e.g. 'ami-0ac4dfaf1c5c0cce9'): " ec2_ami
  read -r -p "Enter instance type (e.g. 't2.micro'): " ec2_type
  echo "Hint: if your Subnet is 'public-tf-sn', reference it with aws_subnet.public-tf-sn.id"
  read -r -p "Enter subnet_id reference (e.g. 'aws_subnet.public-tf-sn.id'): " ec2_subnet
  echo "Hint: for multiple SG references, put them in brackets, e.g. '[aws_security_group.sg-tf.id]'"
  read -r -p "Enter security group references array (e.g. '[aws_security_group.sg-tf.id]'): " ec2_sg_array
  read -r -p "Enter availability zone (e.g. 'us-east-1a'): " ec2_az
  read -r -p "Enter key pair name (e.g. 'key'): " ec2_key
  read -r -p "Enter EC2 instance Tag Name (e.g. 'ec2-terraformed'): " ec2_tag

  MAIN_CONTENT+=$(cat <<EOF
# EC2 Instance
resource "aws_instance" "$ec2_name" {
  ami               = "$ec2_ami"
  instance_type     = "$ec2_type"
  subnet_id         = $ec2_subnet
  security_groups   = $ec2_sg_array
  availability_zone = "$ec2_az"
  key_name          = "$ec2_key"
  tags = {
    Name = "$ec2_tag"
  }
  user_data         = file("\${path.module}/userdata.sh")
}

EOF
)
fi

########################################
# 4) userdata.sh
########################################

create_userdata=$(ask_yes_no "Do you want to create a userdata.sh file?")
USERDATA_CONTENT=""
if [[ "$create_userdata" == "yes" ]]; then
  echo "=== User Data File (userdata.sh) ==="
  echo "Enter the lines for your userdata.sh file."
  echo "When done, press CTRL+D on a new line (in Git Bash or WSL)."
  echo "Example content might be:"
  echo "  #!/bin/bash"
  echo "  yum update -y"
  echo "  yum install httpd -y"
  echo "  cd /var/www/html"
  echo '  echo "<html><body><h1>Hello Terraform $(hostname -f)</h1></body></html>" > index.html'
  echo "  systemctl restart httpd"
  echo "  systemctl enable httpd"
  echo

  # Read multi-line input until EOF (CTRL+D)
  USERDATA_CONTENT="$(</dev/stdin)"
fi

########################################
# 5) Write out the files into ~/ (home dir)
########################################

# 5a) backend.tf
cat <<EOF > ~/backend.tf
terraform {
  backend "s3" {
    bucket = "$s3_bucket"
    key    = "$s3_key"
    region = "$s3_region"
  }
}
EOF

echo "Created ~/backend.tf"

# 5b) provider.tf
cat <<EOF > ~/provider.tf
provider "aws" {
  region = "$provider_region"
}
EOF

echo "Created ~/provider.tf"

# 5c) main.tf
echo "$MAIN_CONTENT" > ~/main.tf
echo "Created ~/main.tf"

# 5d) userdata.sh
if [[ "$create_userdata" == "yes" ]]; then
  echo "$USERDATA_CONTENT" > ~/userdata.sh
  echo "Created ~/userdata.sh"
fi

echo "All requested Terraform files have been created in your home directory (~)."
echo "Done!"