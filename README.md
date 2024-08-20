# CloudAutoScaler


1. Prerequisites 

Before executing the Terraform configuration, ensure the following prerequisites are met: 

AWS Account: An active AWS account with necessary permissions to create and manage resources. 
AWS CLI: AWS Command Line Interface (CLI) installed and configured with access credentials. 
PEM Key: A .pem key file to connect to the EC2 instances via SSH. 
Terraform: Terraform installed on the system where the script will be executed. 


2. Clone the repository
       git clone https://github.com/sivay1998/CloudAutoScaler.git

3. Overview of the Terraform Configuration (main.tf) 

This section describes the Terraform code provided in the main.tf file. 

3.1. Provider Configuration 
                                                    provider "aws" { 
  				region = "us-west-2" 
} 
 
Or 
 
provider "aws" { 
  access_key = "your-access-key" 
  secret_key = "your-secret-key" 
  region     = "us-west-2" 
} 
 
                                                 
 
          Specifies the AWS region (us-west-2) where the resources will be provisioned, access_key and secret_key. 
3.2. VPC and Networking Setup 
VPC: 
                          resource "aws_vpc" "main" { 
 		 cidr_block = "10.0.0.0/16" 
} 
Creates a Virtual Private Cloud (VPC) with a CIDR block of 10.0.0.0/16. 
 

Internet Gateway: 
resource "aws_internet_gateway" "igw" { 
  vpc_id = aws_vpc.main.id 
} 
Enables internet access for resources within the VPC. 
 
Route Table: 
		resource "aws_route_table" "public" { 
  			vpc_id = aws_vpc.main.id 
  			route { 
    				cidr_block = "0.0.0.0/0" 
    				gateway_id = aws_internet_gateway.igw.id 
  				} 
} 
 
     	Routes traffic from the subnets to the Internet Gateway. 
 
3.3. Subnet Configuration 
 
Public Subnets (A, B, C): 
resource "aws_subnet" "subnet_a" { 
  			vpc_id                  = aws_vpc.main.id 
  			cidr_block              = "10.0.1.0/24" 
  			availability_zone       = "us-west-2a" 
  			map_public_ip_on_launch = true 
} 
// Subnet B and Subnet C are similar with different CIDR blocks and availability zones. 
Three subnets are created across different availability zones for high availability. 
 
3.4. Security Group Configuration 
 
Security Group: 
 
resource "aws_security_group" "instance" { 
  				vpc_id      = aws_vpc.main.id 
  				name_prefix = "instance_sg" 
  				ingress { 
    					from_port   = 80 
    					to_port     = 80 
    					protocol    = "tcp" 
    					cidr_blocks = ["0.0.0.0/0"] 
  					} 
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
 
Allows inbound traffic on ports 80 (HTTP) and 22 (SSH) and allows all outbound traffic. 
 
3.5. Launch Configuration 
 
resource "aws_launch_configuration" "web" { 
  			name          = "web-launch-configuration" 
  			image_id      = "ami-074be47313f84fa38" 
  			instance_type = "t2.micro" 
  			key_name      = "poc-aug" 
  			security_groups = [aws_security_group.instance.id] 
  			user_data = <<-EOF 
              					#!/bin/bash 
             	 				sudo yum update -y 
              					sudo yum install python3 -y 
              					sudo pip3 install flask 
              					// Further configuration for app setup 
              					EOF 
} 
 
Defines the instance type, AMI ID, security groups, and a startup script to configure instances. 
 
3.6. Auto Scaling Group Configuration 
 
resource "aws_autoscaling_group" "asg" { 
  				desired_capacity     = 2 
  				max_size             = 5 
  				min_size             = 1 
  				vpc_zone_identifier  = [ 
    					aws_subnet.subnet_a.id, 
    					aws_subnet.subnet_b.id, 
    					aws_subnet.subnet_c.id, 
  				] 
  				launch_configuration = aws_launch_configuration.web.id 
  				tag { 
    					key                 = "Name" 
    					value               = "web-instance" 
    					propagate_at_launch = true 
  					} 
} 
 
Automatically scales the number of EC2 instances based on demand. The configuration includes desired, maximum, and minimum instances. 
 

4. Execution Instructions 
 
Connect to the AWS Server: Use the provided PEM key to SSH into the AWS server. 
 
Run Terraform Commands: Navigate o the directory containing the main.tf file and execute the following Terraform commands: 
 
terraform init 
terraform plan 
terraform apply 
 
5. Test the application: 
 
         1. open any browser and run http://ip_address/ 
                 Results: It works 
 
 
6. Testing Scale-Up Process: 

    
             Simulate Load 

Use Apache Bench (ab) to simulate a heavy load on the application: 
 
 
                     ab -n 100000 -c 100 http://Ip_address/ 
 
               or 
 
      ab –n 200000 –c 500 http://Ip_address/ 
7. Testing Scale-Down Process: 
 
          Reduce Load on Application 

Stop the Apache Bench test or significantly reduce the number of requests: 
    
ab -n 10000 -c 10 http://Ip_address/ 
 
 

8.Destroy configurations 
 
     Run below command: 
 
                  terraform destroy 
 
 
 
 
 
 
 
 
