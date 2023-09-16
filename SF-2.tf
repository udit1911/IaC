provider "aws" {
  region = "ap-south-1"  
}

# ------------------- VPC (Public and Private Subnets with IGW, NAT) ------------------------- #

resource "aws_vpc" "my_vpc" {                       #--------------VPC-------------------#
  cidr_block = "10.0.0.0/16"  
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {              #---------Public Subnet--------------#
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"  
  availability_zone = "ap-south-1a"  
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {              #--------Private Subnet-------------#
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"  
  availability_zone = "ap-south-1b"  
}


resource "aws_internet_gateway" "my_igw"{              #-----------IGW--------------------#
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "public_route_table" {      #-----------route_table------------#
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_nat_gateway" "my_nat_gateway" {        #-------------NAT------------------#
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

resource "aws_eip" "my_eip" {}

resource "aws_route" "private_subnet_nat_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
}


#------------------------------ Create a CMK Key --------------------- #

resource "aws_kms_key" "my_cmk" {
  description             = "My CMK"
  deletion_window_in_days = 7  
  policy = <<-POLICY
  {
    "Version": "2012-10-17",
    "Id": "key",
    "Statement": [
      {
        "Sid": "Enable IAM User Permissions",
        "Effect": "Allow",
        "Principal": {
          "AWS": "*"
        },
        "Action": "kms:*",
        "Resource": "*"
      }
    ]
  }
  POLICY
}

#---------- EC2 Instance in Private Subnet in AZ 1 volumes should be encrypted with the CMK key created in the previous step-----

resource "aws_instance" "my_instance" {
  ami           = "ami-052cef05d01020f1d"  
  instance_type = "t2.micro"     

  subnet_id = aws_subnet.private_subnet.id        #-----------------Private subnet----------------------#



  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    encrypted             = true
    kms_key_id            = aws_kms_key.my_cmk.id  #---------Reference the CMK created earlier----------#
    delete_on_termination = true
  }
}

# ------------------ RDS in Private Subnet in AZ 1 should be encrypted with the CMK key created in the previous step

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name        = "my-db-subnet-group"
  description = "My DB Subnet Group"

  subnet_ids = [aws_subnet.private_subnet.id,aws_subnet.public_subnet.id] #-------------------Private Subnet ID-------------#
  }

resource "aws_db_instance" "my_db_instance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"  
  engine_version       = "5.7"    
  instance_class       = "db.t2.small"  
  username             = "admin"  
  password             = "nimesa2019" 
  skip_final_snapshot  = true
  publicly_accessible  = false

  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name

  kms_key_id = "arn:aws:kms:ap-south-1:815021524419:key/key"            #-------Encryption With CMK Key---------------------#
  storage_encrypted    = true 
}
