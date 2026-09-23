provider "aws" {
  region = "ap-south-1"
}


resource "aws_instance" "tier-3-app" {
  ami           = "ami-01a00762f46d584a1"
  instance_type = "t3.small"

  key_name = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [
    aws_security_group.node_app_sg.id
  ]

  tags = {
    Name = "tier-3-app"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("C:/Users/RITU PRIYA SINGH/Downloads/portfolio-key.pub")
}


resource "aws_security_group" "node_app_sg" {
  name        = "tier-3-app-sg"
  description = "Security group for Node Application"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Frontend Application"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "Backend Application"
    from_port   = 5000
    to_port     = 5000
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
    Name = "tier-3-app-sg"
  }
}


resource "aws_ec2_instance_state" "my_server_state" {
  instance_id = aws_instance.tier-3-app.id
  state       = "running" # Change to "running" to start it back up
}