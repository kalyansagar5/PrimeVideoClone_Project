#!/bin/bash

set -e

echo "======================================"
echo "      DEVOPS SERVER SETUP"
echo "======================================"

# --------------------------------------------------
# Update system
# --------------------------------------------------

echo "Updating system packages..."

sudo apt-get update -y
sudo apt-get upgrade -y

# --------------------------------------------------
# Basic packages
# --------------------------------------------------

echo "Installing basic packages..."

sudo apt-get install -y \
    curl \
    wget \
    unzip \
    ca-certificates \
    gnupg \
    apt-transport-https \
    software-properties-common

# --------------------------------------------------
# AWS CLI
# --------------------------------------------------

echo "======================================"
echo "Installing AWS CLI"
echo "======================================"

if command -v aws >/dev/null 2>&1; then
    echo "AWS CLI already installed."
else
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o /tmp/awscliv2.zip

    rm -rf /tmp/aws

    unzip -q /tmp/awscliv2.zip -d /tmp

    sudo /tmp/aws/install

    rm -rf /tmp/aws /tmp/awscliv2.zip
fi

aws --version

# --------------------------------------------------
# Docker
# --------------------------------------------------

echo "======================================"
echo "Installing Docker"
echo "======================================"

sudo install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    sudo curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
fi

sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

# Add users to Docker group
sudo usermod -aG docker ubuntu || true
sudo usermod -aG docker jenkins || true

# Allow Docker socket access
sudo chmod 666 /var/run/docker.sock

docker --version

# --------------------------------------------------
# SonarQube
# --------------------------------------------------

echo "======================================"
echo "Installing SonarQube"
echo "======================================"

if sudo docker ps -a --format '{{.Names}}' | grep -q "^sonar$"; then
    echo "SonarQube container already exists."
else
    sudo docker run -d \
        --name sonar \
        --restart unless-stopped \
        -p 9000:9000 \
        sonarqube:lts-community
fi

echo "SonarQube container status:"
sudo docker ps --filter "name=sonar"

# --------------------------------------------------
# Trivy
# --------------------------------------------------

echo "======================================"
echo "Installing Trivy"
echo "======================================"

if command -v trivy >/dev/null 2>&1; then
    echo "Trivy already installed."
else

    sudo mkdir -p /usr/share/keyrings

    wget -qO- \
        https://aquasecurity.github.io/trivy-repo/deb/public.key \
        | gpg --dearmor \
        | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
        | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null

    sudo apt-get update -y

    sudo apt-get install -y trivy
fi

trivy --version

# --------------------------------------------------
# Java 17
# --------------------------------------------------

echo "======================================"
echo "Installing Java 17"
echo "======================================"

sudo apt-get install -y \
    openjdk-17-jdk \
    openjdk-17-jre

java -version

# --------------------------------------------------
# Jenkins
# --------------------------------------------------

echo "======================================"
echo "Installing Jenkins"
echo "======================================"

if command -v jenkins >/dev/null 2>&1; then
    echo "Jenkins already installed."
else

    sudo mkdir -p /etc/apt/keyrings

    sudo wget -O \
        /etc/apt/keyrings/jenkins-keyring.asc \
        https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

    echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
        | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    sudo apt-get update -y

    sudo apt-get install -y jenkins
fi

sudo systemctl enable jenkins
sudo systemctl restart jenkins

# Give Jenkins access to Docker
sudo usermod -aG docker jenkins

# --------------------------------------------------
# kubectl
# --------------------------------------------------

echo "======================================"
echo "Installing kubectl"
echo "======================================"

if command -v kubectl >/dev/null 2>&1; then
    echo "kubectl already installed."
else

    curl -LO \
        "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

    sudo install \
        -o root \
        -g root \
        -m 0755 \
        kubectl \
        /usr/local/bin/kubectl

    rm -f kubectl
fi

kubectl version --client

# --------------------------------------------------
# Helm
# --------------------------------------------------

echo "======================================"
echo "Installing Helm"
echo "======================================"

if command -v helm >/dev/null 2>&1; then
    echo "Helm already installed."
else

    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
        | bash
fi

helm version

# --------------------------------------------------
# Permissions for Jenkins
# --------------------------------------------------

echo "======================================"
echo "Configuring Jenkins permissions"
echo "======================================"

sudo usermod -aG docker jenkins

# Make sure Jenkins can execute kubectl and helm
sudo chmod 755 /usr/local/bin/kubectl 2>/dev/null || true
sudo chmod 755 /usr/local/bin/helm 2>/dev/null || true

# --------------------------------------------------
# Restart Jenkins
# --------------------------------------------------

echo "Restarting Jenkins..."

sudo systemctl restart jenkins

# --------------------------------------------------
# Versions / Verification
# --------------------------------------------------

echo "======================================"
echo "      INSTALLATION VERIFICATION"
echo "======================================"

echo ""
echo "AWS:"
aws --version

echo ""
echo "Docker:"
docker --version

echo ""
echo "Java:"
java -version

echo ""
echo "kubectl:"
kubectl version --client

echo ""
echo "Helm:"
helm version

echo ""
echo "Trivy:"
trivy --version

echo ""
echo "Jenkins:"
sudo systemctl is-active jenkins

echo ""
echo "SonarQube:"
sudo docker ps --filter "name=sonar"

# --------------------------------------------------
# Server IP
# --------------------------------------------------

PUBLIC_IP=$(curl -s ifconfig.me || true)

echo ""
echo "======================================"
echo "       ACCESS INFORMATION"
echo "======================================"

echo ""
echo "Jenkins:"
echo "http://${PUBLIC_IP}:8080"

echo ""
echo "SonarQube:"
echo "http://${PUBLIC_IP}:9000"

echo ""
echo "Jenkins Initial Password:"

if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
else
    echo "Password file not available yet."
    echo "Run:"
    echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi

echo ""
echo "======================================"
echo "       SETUP COMPLETED"
echo "======================================"

echo ""
echo "Installed:"
echo "  AWS CLI"
echo "  Docker"
echo "  SonarQube"
echo "  Trivy"
echo "  Java 17"
echo "  Jenkins"
echo "  kubectl"
echo "  Helm"

echo ""
echo "IMPORTANT:"
echo "EKS authentication is intentionally NOT performed here."
echo "Your Jenkins pipelines will run:"
echo ""
echo "aws eks update-kubeconfig \\"
echo "  --region us-east-1 \\"
echo "  --name amazon-prime-cluster"
echo ""
echo "using Jenkins AWS credentials."

echo ""
echo "If Docker access gives a permission error,"
echo "log out and log back in, or restart the Jenkins service."
echo ""
