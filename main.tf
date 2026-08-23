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



