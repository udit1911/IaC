provider "aws" {
  region = "ap-south-1"  
}

resource "aws_instance" "my_instance" {
  ami           = "ami-052cef05d01020f1d"  # Amazon Linux 2 AMI in ap-south-1
  instance_type = "t2.micro"

  tags = {
    Name = "udit-instance"
  }
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "uditupadhyay-bucket"  # Replace with your bucket name
  acl    = "private"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"      # You can customize your cidr_block
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "ec2_sg" {
  name        = "UditEC2SecurityGroup"
  description = "Security group for EC2 instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
