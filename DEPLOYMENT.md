# ☁ AWS Deployment Guide

## 🎯 Objective
Deploy the **Todo application to AWS EC2** Free Tier.

## Prerequisites
- AWS Account
- Key pair created
- Basic AWS knowledge

## 📝 Deployment Steps

### 1. Launch EC2 Instance

```bash
Instance Type: t2.micro (Free Tier)
AMI: Ubuntu 22.04 LTS
Storage: 20GB
Security Group: Allow 22, 80, 443
```
### 2. Connect to Instance
```bash
ssh -i <key-pair> ubuntu@your-ec2-ip
```

### 3. Install Docker
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again
exit
```

### 4. Deploy Application
```bash
# Clone repository
git clone https://github.com/munnavuyyuru/devops-project-1.git
cd devops-project

# Start services
docker compose up -d

# Check status
docker compose ps
```

### 5. Access Application
```bash
http://your-ec2-public-ip
```
### NOTE
 - Replace ec2-ip with your EC2 instance IP address
 - Attach an Elastic IP to get a static public IP address
