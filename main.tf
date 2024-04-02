terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.1"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}


module "my_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "my-vpc-TTT"
  cidr="10.0.0.0/16"
  azs =["us-east-1b"]
  public_subnets=["10.0.101.0/24"]
  tags={
    Terraform ="true"
    Environment ="dev"
  }
 }

 resource "aws_security_group" "allow_ssh_http"{
   name ="allow_ssh_http"
   description ="Allow SSH and HTTP inbound traffic and all outbound traffic"
   vpc_id =module.my_vpc.vpc_id
   tags ={
    Name= "allow-ssh-http"
   }
 }
 # outgoing
 resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
   security_group_id = aws_security_group.allow_ssh_http.id
   cidr_ipv4 = "0.0.0.0/0"
   ip_protocol = "-1"#allports
 }
 # incoming
 resource "aws_vpc_security_group_ingress_rule" "allow_http" {
   security_group_id = aws_security_group.allow_ssh_http.id
   cidr_ipv4 = "0.0.0.0/0"
   ip_protocol = "tcp"
   from_port = 9542
   to_port = 9542
 }
 resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
   security_group_id = aws_security_group.allow_ssh_http.id
   cidr_ipv4 = "0.0.0.0/0"
   ip_protocol = "tcp"
   from_port = 22
   to_port = 22
 }



data "aws_ec2_instance_type" "base_type" {
  instance_type = "t2.micro"
}

data "aws_ami" "base_ami" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

resource "aws_instance" "tic-tac-toe-server" {
  ami = data.aws_ami.base_ami.id
  instance_type = data.aws_ec2_instance_type.base_type.instance_type
  count = "1"
  key_name = "vockey"
  subnet_id = module.my_vpc.public_subnets[0]
  associate_public_ip_address = "true"
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  user_data_replace_on_change = true

  user_data = <<-EOF
        #!/bin/bash
        # Add Docker's official GPG key:
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        # Add the repository to Apt sources:
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        EOF

  tags = {
    Name = "My-Tic-Tac-Toe-Server"
  }
}