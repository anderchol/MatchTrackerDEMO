terraform {
    required_providers {
      aws = { source = "hashicorp/aws", version = "~> 5.0" }
    }
}

provider "aws" {
    region = var.aws_region
}

variable "aws_region" { 
    type = string 
    default = "us-west-2"
}
variable "your_ip" { 
    type = string 
}
variable "instance_count" { 
    type = number 
    default = 1 
}
variable "environment" { 
    type = string 
    default = "dev" 
}
variable "key_name" { 
    type = string 
    default = "matchtracker-key" 
}

# ---DATA SOURCE--- (find latest aws machine image)
data "aws_ami" "amazon_linux" {
    most_recent = true
    owners      = ["amazon"]
    filter { 
        name = "name"               
        values = ["al2023-ami-*-x86_64"] 
    }
    filter { 
        name = "virtualization-type" 
        values = ["hvm"] 
    }
}

# ---SECURITY GROUP---
resource "aws_security_group" "matchtracker" {
    name        = "matchtracker-sg-${var.environment}"
    description = "MatchTracker security group"

    ingress {
        description = "HTTP via Nginx (public)"
        from_port   = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH from dev machine only"
        from_port   = 22
        to_port = 22 
        protocol = "tcp"
        cidr_blocks = [var.your_ip]
    }
    ingress {
        description = "Flask localhost only, Nginx proxies here"
        from_port   = 5000 
        to_port = 5000 
        protocol = "tcp"
        cidr_blocks = ["127.0.0.1/32"]
    }
    egress {
        from_port   = 0 
        to_port = 0 
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = { Name = "matchtracker-sg", Environment = var.environment }
}

# NON-FREE VERSION WITH ASG, WOULD NEED ALB TOO
# # ---EC2 INSTANCE BLUEPRINT---
# resource "aws_launch_template" "matchtracker" {
#     name_prefix            = "matchtracker-lt-"
#     image_id               = data.aws_ami.amazon_linux.id
#     instance_type          = "t2.micro"
#     vpc_security_group_ids = [aws_security_group.matchtracker.id]
#     key_name               = var.key_name

#     user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", 
#                 {
#                     flask_code = file("${path.module}/app/main.py")
#                 }))
    
#     tag_specifications {
#         resource_type = "instance"
#         tags = { Name = "matchtracker-server", Environment = var.environment }
#     }
# }

# # ---ASG (Auto Scaling Group)---
# resource "aws_autoscaling_group" "matchtracker" {
#     name             = "matchtracker-asg-${var.environment}"
#     desired_capacity = var.instance_count
#     min_size         = 1
#     max_size         = 3
#     availability_zones = ["${var.aws_region}a"]

#     launch_template {
#         id      = aws_launch_template.matchtracker.id
#         version = "$Latest"
#     }

#     health_check_type         = "EC2"
#     health_check_grace_period = 120

#     tag { 
#         key = "Name"
#         value = "matchtracker-server"
#         propagate_at_launch = true 
#     }

# }

# ---EC2 Instance---
resource "aws_instance" "matchtracker" {
    count = var.instance_count
    ami                    = data.aws_ami.amazon_linux.id
    instance_type          = "t2.micro"
    key_name               = var.key_name
    vpc_security_group_ids = [aws_security_group.matchtracker.id]

    user_data = templatefile("${path.module}/userdata.sh.tpl", {
        flask_code = file("${path.module}/app/main.py")
    })

    tags = {
        Name = "matchtracker-${count.index}"
        Environment = var.environment
    }
}

# ---Elastic IP---
resource "aws_eip" "matchtracker" {
    count = var.instance_count
    instance = aws_instance.matchtracker[count.index].id
    domain = "vpc"
    tags   = { 
        Name = "matchtracker-eip-${count.index}"
        Environment = var.environment 
    }
}



output "elastic_ip"       { value = aws_eip.matchtracker.public_ip }
output "app_url"          { value = "http://${aws_eip.matchtracker.public_ip}" }
output "health_url"       { value = "http://${aws_eip.matchtracker.public_ip}/health" }
output "ssh_command"      { value = "ssh -i ~/.ssh/matchtracker-key.pem ec2-user@${aws_eip.matchtracker.public_ip}" }
output "hosts_file_entry" { value = "${aws_eip.matchtracker.public_ip}  matchtracker.local" }
output "asg_name"         { value = aws_autoscaling_group.matchtracker.name }
