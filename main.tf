//Author Sriram and KiranRaj

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    } 
  }
}

provider "aws" {
  region = "us-east-1"
#  access_key = var.aws_access_key
#  secret_key = var.aws_secret_key
}

#key pair creation
resource "aws_key_pair" "tf-key-pair" {
key_name = "tf-key-pair"
public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
algorithm = "RSA"
rsa_bits  = 4096
}
resource "local_file" "tf-key" {
content  = tls_private_key.rsa.private_key_pem
filename = "tf-key-pair"
}

#VPC creation
resource "aws_vpc" "VPCFROMTF" {
  cidr_block = "10.0.0.0/16" 
  tags = {
        Name = "TFVPC"
  }
}

#Adding Internet Gateway to VPC
resource "aws_internet_gateway" "IGWFROMTF" {
  #Name="IGWFROMTF"
  vpc_id = aws_vpc.VPCFROMTF.id

  tags = {
    "name" = "TFIGW"
  }  
}

#Subnet creation
resource "aws_subnet" "SUBNETFROMTF" {
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b" 
  vpc_id= aws_vpc.VPCFROMTF.id
  tags = {
        Name = "TFSUBNET"
  }
  
}

#Route table creation
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.VPCFROMTF.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGWFROMTF.id
  }

  tags = {
    Name = "RT"
  }
}

# Associating route table to subnet
resource "aws_route_table_association" "RTA" {
  subnet_id      = aws_subnet.SUBNETFROMTF.id
  route_table_id = aws_route_table.RT.id
}

#EC2 Creation
#1st Windows server

resource "aws_instance" "Win-1" {
  ami = "ami-0fc682b2a42e57ca2"
  subnet_id = aws_subnet.SUBNETFROMTF.id
  instance_type = "t2.micro"
  key_name = "tf-key-pair"
  associate_public_ip_address = true
  user_data = <<-EOF
    <powershell>
    $username = "Ansible"
    $password = "Wipro@123"
    net user $username $password /add
    net localgroup administrators $username /add
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    Set-Item -Force WSMan:\localhost\Service\auth\Basic $true
    </powershell>
  EOF
  tags ={
  Name="Win-1"
}
}

#2nd Windows server

resource "aws_instance" "Win-2" {
  ami = "ami-0fc682b2a42e57ca2"
  subnet_id = aws_subnet.SUBNETFROMTF.id
  instance_type = "t2.micro"
  key_name = "tf-key-pair"
  associate_public_ip_address = true
  user_data = <<-EOF
    <powershell>
    $username = "Ansible"
    $password = "Wipro@123"
    net user $username $password /add
    net localgroup administrators $username /add
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    Set-Item -Force WSMan:\localhost\Service\auth\Basic $true
    </powershell>
  EOF
  tags ={
  Name="Win-2"
}
}

#3rd Windows server
resource "aws_instance" "Win-3" {
  ami = "ami-0fc682b2a42e57ca2"
  subnet_id = aws_subnet.SUBNETFROMTF.id
  instance_type = "t2.micro"
  key_name = "tf-key-pair"
  associate_public_ip_address = true

  user_data = <<-EOF
    <powershell>
    $username = "Ansible"
    $password = "Wipro@123"
    net user $username $password /add
    net localgroup administrators $username /add
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    Set-Item -Force WSMan:\localhost\Service\auth\Basic $true
    </powershell>
  EOF

  tags ={
  Name="Win-3"
}
}

#Ansible master server

resource "aws_instance" "Ansible-Master" {
  ami = "ami-0149b2da6ceec4bb0"
  subnet_id = aws_subnet.SUBNETFROMTF.id
  instance_type = "t2.micro"
  key_name = "tf-key-pair"
  associate_public_ip_address = true
  user_data = <<-EOF
    #!/bin/bash 
    sudo apt update -y
    sudo apt install ansible -y
    echo "[win]" | sudo tee -a /etc/ansible/hosts
    echo "${aws_instance.Win-1.private_ip}" >> /etc/ansible/hosts
    echo "${aws_instance.Win-2.private_ip}" >> /etc/ansible/hosts
    echo "${aws_instance.Win-3.private_ip}" >> /etc/ansible/hosts
    echo "[win:vars]" | sudo tee -a /etc/ansible/hosts
    echo "ansible_user=Ansible" | sudo tee -a /etc/ansible/hosts
    echo "ansible_password=Wipro@123" | sudo tee -a /etc/ansible/hosts
    echo "ansible_connection=winrm" | sudo tee -a /etc/ansible/hosts
    echo "ansible_winrm_server_cert_validation=ignore" | sudo tee -a /etc/ansible/hosts
    echo "ansible_winrm_scheme=http" | sudo tee -a /etc/ansible/hosts
    echo "ansible_port=5985" | sudo tee -a /etc/ansible/hosts
    echo "Hello, World!" > hello.txt
    EOF           

  tags ={
  Name="Ansible-Master"
}
}



#Creating Security group and applying ingress & egress

resource "aws_security_group" "allow_full" {
  name        = "allow_full"
  description = "Full open"
  vpc_id      = aws_vpc.VPCFROMTF.id

  ingress {
    description      = "allow_full"
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
  }
    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    tags = {
    Name = "allow_All"
  }
}

#Attach Security group to each EC2's Network interface

resource "aws_network_interface_sg_attachment" "sg_Ansible-Master" {
  security_group_id    = aws_security_group.allow_full.id
  network_interface_id = aws_instance.Ansible-Master.primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "sg_Win-1" {
  security_group_id    = aws_security_group.allow_full.id
  network_interface_id = aws_instance.Win-1.primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "sg_Win-2" {
  security_group_id    = aws_security_group.allow_full.id
  network_interface_id = aws_instance.Win-2.primary_network_interface_id
}


resource "aws_network_interface_sg_attachment" "sg_Win-3" {
  security_group_id    = aws_security_group.allow_full.id
  network_interface_id = aws_instance.Win-3.primary_network_interface_id
}
