#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting installation of Jenkins Kubernetes Dynamic Agents POC..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status messages
print_status() {
    echo "📝 $1"
}

# Function to print success messages
print_success() {
    echo "✅ $1"
}

# Function to print error messages
print_error() {
    echo "❌ $1"
}

# Function to check if running in a VM
is_vm() {
    if command_exists systemd-detect-virt; then
        systemd-detect-virt | grep -q "vmware\|virtualbox\|kvm\|qemu"
        return $?
    fi
    return 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Update system
print_status "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
print_status "Installing required packages..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg \
    lsb-release \
    systemd-container

# Install Docker if not present
if ! command_exists docker; then
    print_status "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    systemctl enable docker
    systemctl start docker
    print_success "Docker installed successfully"
else
    print_success "Docker is already installed"
fi

# Configure Docker permissions
# print_status "Configuring Docker permissions..."
# SUDO_USER=${SUDO_USER:-$USER}
# usermod -aG docker $SUDO_USER
# newgrp docker
# print_success "Docker permissions configured"

# Install Minikube if not present
if ! command_exists minikube; then
    print_status "Installing Minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
    print_success "Minikube installed successfully"
else
    print_success "Minikube is already installed"
fi

# Install kubectl if not present
if ! command_exists kubectl; then
    print_status "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    print_success "kubectl installed successfully"
else
    print_success "kubectl is already installed"
fi

# Determine Minikube driver
if is_vm; then
    print_status "Running in a VM, using 'none' driver..."
    MINIKUBE_DRIVER="none"
else
    print_status "Running on physical machine, using 'docker' driver..."
    MINIKUBE_DRIVER="docker"
fi

# Start Minikube
print_status "Starting Minikube with $MINIKUBE_DRIVER driver..."
if [ "$MINIKUBE_DRIVER" = "none" ]; then
    minikube start --driver=none
else
    minikube start --driver=docker
fi

# Enable Minikube addons
print_status "Enabling Minikube addons..."
minikube addons enable ingress
minikube addons enable metrics-server

print_success "Installation completed successfully!"
echo "🌐 Minikube IP: $(minikube ip)"
echo "📝 Next steps:"
echo "1. Configure Kubernetes cloud in Jenkins:"
echo "   - Go to Manage Jenkins > Configure Clouds"
echo "   - Add a new cloud (Kubernetes)"
echo "   - Set Kubernetes URL to: https://kubernetes.default.svc.cluster.local"
echo "   - Set Jenkins URL to: http://$(hostname -I | awk '{print $1}'):8080"
echo "   - Set Jenkins tunnel to: $(hostname -I | awk '{print $1}'):50000"
echo "   - Set Pod template to use the jenkins-agent.yaml file"
echo "2. Create a new Pipeline job to test dynamic agents" 