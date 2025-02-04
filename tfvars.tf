variable "vpc-cidr" {
  type        = string               # optional
  description = "the VPC CIDR block" # optional
  default     = "100.64.0.0/16"
}

variable "pub-cidr" {
  type        = string
  description = "the public subnet address"
  default     = "100.64.1.0/24"
}


variable "priv-cidr" {
  type        = string
  description = "the private subnet address"
  default     = "100.64.2.0/24"
}

variable "chassis" {
  type        = string
  description = "the chassis of the AMI image"
  default     = "t2.micro"
}

data "aws_ami" "latest_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
