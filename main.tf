terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.56"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


# Data source to use the default VPC
data "aws_vpc" "default" {
  default = true
}


# Data source to get a specific default subnet
data "aws_subnet" "default" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "availability-zone"
    values = ["us-east-1a"] 
  }
}



# Create Security Group
resource "aws_security_group" "allow_ssh_http_https" {
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh-http"
  }
}

# Create SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "./.ssh/terraform_rsa"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "./.ssh/terraform_rsa.pub"
}

resource "aws_key_pair" "deployer" {
  key_name   = "ubuntu_ssh_key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}


# Create Ubuntu EC2 Instance
resource "aws_instance" "ubuntu_instance" {
  ami                         = "ami-0a0e5d9c7acc336f1"
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh_http_https.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true


  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y nginx
              
              # Create index.html with H1 tag in the default NGINX web directory
              echo "<h1>Hello From Ubuntu EC2 Instance!!!</h1>" | sudo tee /var/www/html/index.html
              
              # Restart NGINX to apply the changes
              sudo systemctl restart nginx
              EOF

  tags = {
    Name = "ubuntu-instance"
  }
}

# Output the Public IPs
output "ubuntu_instance_public_ip" {
  value = aws_instance.ubuntu_instance.public_ip
}

# Output VPC CIDR Block
output "vpc_cidr_block" {
  value = data.aws_vpc.default.cidr_block
  description = "The CIDR block of the default VPC"
}

# Output Subnet CIDR Block
output "subnet_cidr_block" {
  value = data.aws_subnet.default.cidr_block
  description = "The CIDR block of the default subnet"
}