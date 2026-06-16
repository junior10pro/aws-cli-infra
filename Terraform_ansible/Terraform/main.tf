provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids      = [aws_security_group.wendyam_junior-sg.id]
  subnet_id                   = aws_subnet.wendyam_junior-subnet.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.wendyam_junior-key.key_name

  user_data = <<-EOF
  #!/bin/bash
  apt update -y
  apt install -y nginx
  systemctl start nginx
  systemctl enable nginx
  cat > /var/www/html/index.html << 'HTML'
  ${templatefile("../ansible/templates/index.html.j2", {
    hostname = "wendyam-junior",
    ip       = "auto"
  })}
  HTML
EOF


  tags = {
    Name = var.instance_name
  }
}

resource "aws_key_pair" "wendyam_junior-key" {
  key_name   = "wendyam_junior-key"
  public_key = file("C:/Users/xyzkj/Claude/aws-cli-v1/Terraform_ansible/Terraform/wendyam_junior-key.pub")
}

resource "aws_subnet" "wendyam_junior-subnet" {
  vpc_id            = "vpc-0ebcdb39f7a526ef9"
  cidr_block        = "172.31.150.0/24"
  availability_zone = "eu-west-3a"
  map_public_ip_on_launch = true  # ajoute cette ligne
  
  tags = {
    Name = "wendyam_junior-subnet"
  }
}

resource "aws_security_group" "wendyam_junior-sg" {
  name   = "wendyam_junior-sg"
  vpc_id = "vpc-0ebcdb39f7a526ef9"

  # INGRESS — trafic entrant
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Remplace par ton IP pour plus de sécurité
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # EGRESS — trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # -1 = tout autoriser
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wendyam_junior-sg"
  }
}

