#!/bin/bash
set -e
yum update -y
yum install -y python3 python3-pip nginx make
mkdir -p /opt/matchtracker

# OpenTofu will drop your entire app.py code right here!
cat > /opt/matchtracker/main.py << 'PYEOF'
${flask_code}
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
        proxy_read_timeout 30s;
    }
}
NGINXEOF

rm -f /etc/nginx/conf.d/default.conf
systemctl enable nginx
systemctl restart nginx
