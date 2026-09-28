#!/bin/bash

set -e

# ============================================================
# DEVOPS EC2 SETUP
# Ubuntu EC2
# ============================================================

echo "========================================="
echo " DEVOPS SERVER SETUP STARTED"
echo "========================================="

# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------

LOG_FILE="/var/log/devops-setup.log"

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

echo
echo "Setup started at: $(date)"
echo

# ============================================================
# SYSTEM UPDATE
# ============================================================

echo "========================================="
echo " UPDATING SYSTEM"
echo "========================================="

apt-get update -y
apt-get upgrade -y

# ============================================================
# BASIC PACKAGES
# ============================================================

echo "========================================="
echo " INSTALLING BASIC PACKAGES"
echo "========================================="

apt-get install -y \
    curl \
    wget \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    git \
    jq \
    vim \
    net-tools \
    tar \
    gzip

# ============================================================
# AWS CLI V2
# ============================================================

echo "========================================="
echo " INSTALLING AWS CLI V2"
echo "========================================="

if command -v aws >/dev/null 2>&1; then

    echo "AWS CLI already installed."

else

    cd /tmp

    rm -rf aws
    rm -f awscliv2.zip

    curl -fsSL \
        "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o awscliv2.zip

    unzip -q awscliv2.zip

    ./aws/install

    rm -rf /tmp/aws
    rm -f /tmp/awscliv2.zip

fi

echo
echo "AWS CLI version:"
aws --version

# ============================================================
# DOCKER
# ============================================================

echo "========================================="
echo " INSTALLING DOCKER"
echo "========================================="

install -m 0755 -d /etc/apt/keyrings

rm -f /etc/apt/keyrings/docker.asc

curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release

cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable
EOF

apt-get update -y

apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker

if id ubuntu >/dev/null 2>&1; then
    usermod -aG docker ubuntu
fi

echo
echo "Docker version:"
docker --version

echo
echo "Docker Compose version:"
docker compose version

# ============================================================
# JAVA 21
# ============================================================

echo "========================================="
echo " INSTALLING JAVA 21"
echo "========================================="

apt-get install -y \
    openjdk-21-jdk \
    openjdk-21-jre

JAVA_HOME_PATH="/usr/lib/jvm/java-21-openjdk-amd64"

if [ -d "$JAVA_HOME_PATH" ]; then

    update-alternatives \
        --set java \
        "$JAVA_HOME_PATH/bin/java" || true

    update-alternatives \
        --set javac \
        "$JAVA_HOME_PATH/bin/javac" || true

    cat > /etc/profile.d/java.sh <<EOF
export JAVA_HOME=$JAVA_HOME_PATH
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

    chmod 644 /etc/profile.d/java.sh

    export JAVA_HOME="$JAVA_HOME_PATH"
    export PATH="$JAVA_HOME/bin:$PATH"

fi

echo
echo "Java version:"
java -version

echo
echo "JAVA_HOME:"
echo "$JAVA_HOME"

# ============================================================
# KUBECTL
# ============================================================

echo "========================================="
echo " INSTALLING KUBECTL"
echo "========================================="

mkdir -p /etc/apt/keyrings

rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

curl -fsSL \
    https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
    | gpg --dearmor \
    -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /
EOF

apt-get update -y

apt-get install -y kubectl

echo
echo "kubectl version:"
kubectl version --client

# ============================================================
# HELM
# ============================================================

echo "========================================="
echo " INSTALLING HELM"
echo "========================================="

# Remove any broken Helm repository from previous runs
rm -f /etc/apt/sources.list.d/helm-stable-debian.list
rm -f /usr/share/keyrings/helm.gpg

# If Helm already exists, keep it
if command -v helm >/dev/null 2>&1; then

    echo "Helm already installed."

else

    echo "Downloading Helm installer..."

    cd /tmp

    rm -f get_helm.sh

    curl -fsSL \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
        -o get_helm.sh

    chmod 700 get_helm.sh

    ./get_helm.sh

    rm -f get_helm.sh

fi

if ! command -v helm >/dev/null 2>&1; then
    echo "ERROR: Helm installation failed."
    exit 1
fi

echo
echo "Helm version:"
helm version

# ============================================================
# TRIVY
# ============================================================

echo "========================================="
echo " INSTALLING TRIVY"
echo "========================================="

mkdir -p /etc/apt/keyrings

rm -f /etc/apt/keyrings/trivy.gpg

curl -fsSL \
    https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | gpg --dearmor \
    -o /etc/apt/keyrings/trivy.gpg

chmod 644 /etc/apt/keyrings/trivy.gpg

cat > /etc/apt/sources.list.d/trivy.list <<EOF
deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main
EOF

apt-get update -y

apt-get install -y trivy

echo
echo "Trivy version:"
trivy --version

# ============================================================
# SONARQUBE SYSTEM CONFIGURATION
# ============================================================

echo "========================================="
echo " CONFIGURING SONARQUBE"
echo "========================================="

cat > /etc/sysctl.d/99-sonarqube.conf <<EOF
vm.max_map_count=524288
fs.file-max=131072
EOF

sysctl --system

# ============================================================
# SONARQUBE
# ============================================================

echo "========================================="
echo " INSTALLING SONARQUBE"
echo "========================================="

docker rm -f sonar 2>/dev/null || true

echo "Pulling SonarQube image..."

docker pull sonarqube:lts-community

echo "Starting SonarQube..."

docker run -d \
    --name sonar \
    --restart unless-stopped \
    -p 9000:9000 \
    sonarqube:lts-community

echo
echo "SonarQube container started."

# ============================================================
# WAIT FOR SONARQUBE
# ============================================================

echo "========================================="
echo " WAITING FOR SONARQUBE"
echo "========================================="

SONAR_READY=false

for i in $(seq 1 60); do

    STATUS=$(curl -s \
        --max-time 5 \
        http://127.0.0.1:9000/api/system/status \
        2>/dev/null || true)

    if echo "$STATUS" | grep -q '"status":"UP"'; then

        echo "SonarQube is UP."

        SONAR_READY=true

        break

    fi

    echo "Waiting for SonarQube... $i/60"

    sleep 5

done

if [ "$SONAR_READY" = false ]; then

    echo "WARNING: SonarQube did not reach UP state yet."

    docker ps -a --filter "name=sonar"

    echo
    echo "Last SonarQube logs:"

    docker logs --tail 50 sonar || true

fi

# ============================================================
# JENKINS
# ============================================================

echo "========================================="
echo " INSTALLING JENKINS"
echo "========================================="

mkdir -p /etc/apt/keyrings

rm -f /etc/apt/keyrings/jenkins-keyring.asc

wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

chmod 644 /etc/apt/keyrings/jenkins-keyring.asc

cat > /etc/apt/sources.list.d/jenkins.list <<EOF
deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/
EOF

apt-get update -y

apt-get install -y jenkins

# ============================================================
# JENKINS + DOCKER
# ============================================================

echo "========================================="
echo " CONFIGURING JENKINS"
echo "========================================="

usermod -aG docker jenkins

systemctl daemon-reload

systemctl enable jenkins
systemctl restart jenkins

# ============================================================
# WAIT FOR JENKINS
# ============================================================

echo "========================================="
echo " WAITING FOR JENKINS"
echo "========================================="

JENKINS_READY=false

for i in $(seq 1 60); do

    if systemctl is-active --quiet jenkins; then

        echo "Jenkins is running."

        JENKINS_READY=true

        break

    fi

    echo "Waiting for Jenkins... $i/60"

    sleep 2

done

if [ "$JENKINS_READY" = false ]; then

    echo
    echo "WARNING: Jenkins did not start."

    systemctl status jenkins --no-pager -l || true

fi

# ============================================================
# JENKINS INITIAL PASSWORD
# ============================================================

JENKINS_PASSWORD=""

if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then

    JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)

else

    echo "Jenkins initial password not available yet."

fi

# ============================================================
# GET PUBLIC IP
# ============================================================

echo "========================================="
echo " GETTING PUBLIC IP"
echo "========================================="

PUBLIC_IP=""

PUBLIC_IP=$(curl -fsS \
    --max-time 10 \
    https://checkip.amazonaws.com \
    2>/dev/null || true)

PUBLIC_IP=$(echo "$PUBLIC_IP" | tr -d '[:space:]')

if [ -z "$PUBLIC_IP" ]; then

    PUBLIC_IP=$(curl -fsS \
        --max-time 10 \
        https://ifconfig.me \
        2>/dev/null || true)

    PUBLIC_IP=$(echo "$PUBLIC_IP" | tr -d '[:space:]')

fi

# ============================================================
# SAVE SERVER INFORMATION
# ============================================================

cat > /root/devops-info.txt <<EOF
=========================================
DEVOPS SERVER INFORMATION
=========================================

PUBLIC IP:
${PUBLIC_IP}

JENKINS:
http://${PUBLIC_IP}:8080

JENKINS INITIAL ADMIN PASSWORD:
${JENKINS_PASSWORD}

SONARQUBE:
http://${PUBLIC_IP}:9000

SONARQUBE DEFAULT LOGIN:
Username: admin
Password: admin

=========================================
INSTALLED TOOLS
=========================================

AWS:
$(aws --version 2>&1)

Docker:
$(docker --version 2>&1)

Docker Compose:
$(docker compose version 2>&1)

Java:
$(java -version 2>&1 | head -1)

kubectl:
$(kubectl version --client 2>&1)

Helm:
$(helm version 2>&1)

Trivy:
$(trivy --version 2>&1)

=========================================
EOF

chmod 600 /root/devops-info.txt

# ============================================================
# FINAL VERIFICATION
# ============================================================

echo
echo "========================================="
echo " FINAL VERIFICATION"
echo "========================================="

echo
echo "AWS CLI:"
aws --version

echo
echo "Docker:"
docker --version

echo
echo "Docker Compose:"
docker compose version

echo
echo "Java:"
java -version

echo
echo "kubectl:"
kubectl version --client

echo
echo "Helm:"
helm version

echo
echo "Trivy:"
trivy --version

echo
echo "Jenkins:"
systemctl is-active jenkins || true

echo
echo "SonarQube:"
docker ps --filter "name=sonar"

# ============================================================
# FINAL OUTPUT
# ============================================================

echo
echo "========================================="
echo " DEVOPS SETUP COMPLETED"
echo "========================================="

echo
echo "Public IP:"
echo "$PUBLIC_IP"

echo
echo "Jenkins:"
echo "http://${PUBLIC_IP}:8080"

echo
echo "Jenkins Initial Admin Password:"
echo "$JENKINS_PASSWORD"

echo
echo "SonarQube:"
echo "http://${PUBLIC_IP}:9000"

echo
echo "SonarQube Login:"
echo "Username: admin"
echo "Password: admin"

echo
echo "Information file:"
echo "/root/devops-info.txt"

echo
echo "Setup log:"
echo "/var/log/devops-setup.log"

echo
echo "========================================="
echo " KUBERNETES / EKS"
echo "========================================="

echo
echo "kubectl and Helm are installed."

echo
echo "To connect to EKS:"

echo "aws eks update-kubeconfig --region <REGION> --name <CLUSTER_NAME>"

echo
echo "Then:"

echo "kubectl get nodes"
echo "kubectl get pods -A"
echo "helm list -A"

echo
echo "========================================="
echo " SETUP FINISHED"
echo "========================================="
