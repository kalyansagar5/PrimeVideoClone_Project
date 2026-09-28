terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.67.0"
    }
  }
}

provider "aws" {
  region = var.region_name
}

# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "my-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "JENKINS-VPC"
  }
}

# ============================================================
# PUBLIC SUBNET
# ============================================================

resource "aws_subnet" "my-public-subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region_name}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "JENKINS-PUBLIC-SUBNET"
  }
}

# ============================================================
# INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "JENKINS-IGW"
  }
}

# ============================================================
# PUBLIC ROUTE TABLE
# ============================================================

resource "aws_route_table" "my-public-rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }

  tags = {
    Name = "JENKINS-PUBLIC-ROUTE-TABLE"
  }
}

# ============================================================
# ROUTE TABLE ASSOCIATION
# ============================================================

resource "aws_route_table_association" "my-public-rta" {
  subnet_id      = aws_subnet.my-public-subnet.id
  route_table_id = aws_route_table.my-public-rt.id
}

# ============================================================
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "my-sg" {
  name        = "JENKINS-SERVER-SG"
  description = "Security group for Jenkins and SonarQube"
  vpc_id      = aws_vpc.my-vpc.id

  # ----------------------------------------------------------
  # SSH
  # ----------------------------------------------------------

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    # For production, change this to YOUR_PUBLIC_IP/32
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ----------------------------------------------------------
  # Jenkins
  # ----------------------------------------------------------

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ----------------------------------------------------------
  # SonarQube
  # ----------------------------------------------------------

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ----------------------------------------------------------
  # HTTP
  # ----------------------------------------------------------

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ----------------------------------------------------------
  # HTTPS
  # ----------------------------------------------------------

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ----------------------------------------------------------
  # OUTBOUND
  # ----------------------------------------------------------

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "JENKINS-SERVER-SG"
  }
}

# ============================================================
# EC2 INSTANCE
# ============================================================

resource "aws_instance" "my-ec2" {

  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name

  # Public subnet
  subnet_id = aws_subnet.my-public-subnet.id

  # Security group
  vpc_security_group_ids = [
    aws_security_group.my-sg.id
  ]

  # Root disk
  root_block_device {
    volume_size = var.volume_size
  }

  tags = {
    Name = var.server_name
  }

  # ==========================================================
  # COPY setup.sh TO EC2
  # ==========================================================

  provisioner "file" {

    source      = "${path.module}/setup.sh"
    destination = "/tmp/setup.sh"

    connection {
      type        = "ssh"
      private_key = file("${path.module}/key.pem")
      user        = "ubuntu"
      host        = self.public_ip
    }
  }

  # ==========================================================
  # EXECUTE setup.sh
  # ==========================================================

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      private_key = file("${path.module}/key.pem")
      user        = "ubuntu"
      host        = self.public_ip
    }

    inline = [

      "echo '========================================='",
      "echo 'Checking setup.sh'",
      "echo '========================================='",

      # Check file exists
      "ls -lah /tmp/setup.sh",
      "test -f /tmp/setup.sh",

      # ------------------------------------------------------
      # IMPORTANT:
      # Convert Windows CRLF to Linux LF
      # ------------------------------------------------------

      "sed -i 's/\\r$//' /tmp/setup.sh",

      # Make executable
      "chmod +x /tmp/setup.sh",

      # Show first line for verification
      "echo 'First line of setup.sh:'",
      "head -n 1 /tmp/setup.sh",

      # Execute
      "sudo /tmp/setup.sh"
    ]
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "SERVER-SSH-ACCESS" {
  value = "ubuntu@${aws_instance.my-ec2.public_ip}"
}

output "PUBLIC-IP" {
  value = aws_instance.my-ec2.public_ip
}

output "PRIVATE-IP" {
  value = aws_instance.my-ec2.private_ip
}

output "VPC-ID" {
  value = aws_vpc.my-vpc.id
}

output "PUBLIC-SUBNET-ID" {
  value = aws_subnet.my-public-subnet.id
}

output "INTERNET-GATEWAY-ID" {
  value = aws_internet_gateway.my-igw.id
}

output "ROUTE-TABLE-ID" {
  value = aws_route_table.my-public-rt.id
}

output "JENKINS-URL" {
  value = "http://${aws_instance.my-ec2.public_ip}:8080"
}

output "SONARQUBE-URL" {
  value = "http://${aws_instance.my-ec2.public_ip}:9000"
}
