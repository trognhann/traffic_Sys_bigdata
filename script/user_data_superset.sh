#!/bin/bash
dnf update -y
dnf install -y docker git
service docker start
usermod -a -G docker ec2-user

# Cài Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Pull & Run Superset (Dùng image chính chủ)
mkdir /home/ec2-user/superset
cd /home/ec2-user/superset

cat <<EOF > docker-compose.yml
version: '3'
services:
  superset:
    image: apache/superset
    ports:
      - "8088:8088"
    environment:
      - SUPERSET_SECRET_KEY=$(openssl rand -base64 42)
    command: >
      bash -c "
        superset fab create-admin --username admin --firstname Superset --lastname Admin --email admin@fab.org --password admin &&
        superset db upgrade &&
        superset init &&
        /usr/bin/run-server.sh"
EOF

docker-compose up -d