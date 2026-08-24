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
        description = "Flask — localhost only, Nginx proxies here"
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

# ---EC2 INSTANCE BLUEPRINT---
resource "aws_launch_template" "matchtracker" {
    name_prefix            = "matchtracker-lt-"
    image_id               = data.aws_ami.amazon_linux.id
    instance_type          = "t2.micro"
    vpc_security_group_ids = [aws_security_group.matchtracker.id]
    key_name               = var.key_name

    user_data = base64encode(<<-"USERDATA"
        #!/bin/bash
        set -e
        yum update -y
        yum install -y python3 python3-pip nginx make
        mkdir -p /opt/matchtracker
    
        # Write Flask app
        cat > /opt/matchtracker/main.py << PYEOF
        ... (paste app/main.py contents here)
        PYEOF
    
        pip3 install flask
    
        # Write Makefile for server-side commands
        cat > /opt/matchtracker/Makefile << MKEOF
        .PHONY: status logs restart health
        status:
        systemctl status matchtracker
        logs:
        journalctl -u matchtracker -f
        restart:
        systemctl restart matchtracker
        health:
        curl -s http://localhost/health | python3 -m json.tool
        MKEOF
    
        # systemd service — keeps Flask alive
        cat > /etc/systemd/system/matchtracker.service << SVCEOF
        [Unit]
        Description=MatchTracker Flask
        After=network.target
        [Service]
        ExecStart=/usr/bin/python3 /opt/matchtracker/main.py
        WorkingDirectory=/opt/matchtracker
        Restart=always
        RestartSec=3
        Environment=ENVIRONMENT=aws-ec2
        [Install]
        WantedBy=multi-user.target
        SVCEOF
    
        systemctl daemon-reload
        systemctl enable matchtracker
        systemctl start matchtracker
    
        # Nginx reverse proxy
        cat > /etc/nginx/conf.d/matchtracker.conf << NGINXEOF
        upstream matchtracker_backend { 
            server 127.0.0.1:5000; 
        }
        server {
            listen 80;
            location / {
                proxy_pass http://matchtracker_backend;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_connect_timeout 5s;
                proxy_read_timeout    30s;
            }
        }
        NGINXEOF
    
        rm -f /etc/nginx/conf.d/default.conf
        systemctl enable nginx
        systemctl restart nginx
    USERDATA)
    
    tag_specifications {
        resource_type = "instance"
        tags = { Name = "matchtracker-server", Environment = var.environment }
    }
}