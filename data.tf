# Le VPC est lu via son ID — Terraform ne le gère jamais (data source = lecture seule)
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Le subnet public est lu via son ID — idem, lecture seule
data "aws_subnet" "public_a" {
  id = var.subnet_public_id
}

# Dernière AMI Amazon Linux 2023 x86_64
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Dernière AMI Ubuntu 22.04 LTS x86_64 (Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}
