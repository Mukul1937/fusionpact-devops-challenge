#!/usr/bin/env bash
# ============================================================
# AWS EC2 Setup Script
# Run this on a fresh Ubuntu 22.04 EC2 instance
# ============================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${CYAN}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}? $1${NC}"; }
warn() { echo -e "${YELLOW}??  $1${NC}"; }
error() { echo -e "${RED}? $1${NC}"; exit 1; }

echo -e "${CYAN}"
echo "ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»"
echo "º   Fusionpact DevOps Gauntlet - AWS EC2 Setup    º"
echo "ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼"
echo -e "${NC}"

# ÄÄ System Update ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y
success "System updated"

# ÄÄ Install Essential Tools ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Installing essential tools..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    htop \
    net-tools \
    ufw \
    make \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

success "Essential tools installed"

# ÄÄ Install Docker ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    success "Docker installed: $(docker --version)"
else
    warn "Docker already installed: $(docker --version)"
fi

# ÄÄ Install Docker Compose ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION="v2.23.0"
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    success "Docker Compose installed: $(docker-compose --version)"
else
    warn "Docker Compose already installed: $(docker-compose --version)"
fi

# ÄÄ Configure Firewall (UFW) ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh                  # 22
sudo ufw allow 80/tcp               # HTTP Frontend
sudo ufw allow 443/tcp              # HTTPS
sudo ufw allow 8000/tcp             # Backend API
sudo ufw allow 3000/tcp             # Grafana
sudo ufw allow 9090/tcp             # Prometheus
sudo ufw allow 9093/tcp             # AlertManager
sudo ufw allow 8080/tcp             # cAdvisor
sudo ufw allow 9100/tcp             # Node Exporter
sudo ufw --force enable
success "Firewall configured"

# ÄÄ Install AWS CLI ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Installing AWS CLI..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
    success "AWS CLI installed: $(aws --version)"
fi

# ÄÄ Clone Repository ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Cloning Fusionpact repository..."
REPO_DIR="$HOME/fusionpact-devops-challenge"
if [ ! -d "$REPO_DIR" ]; then
    git clone https://github.com/YOUR_USERNAME/fusionpact-devops-challenge.git "$REPO_DIR"
    success "Repository cloned"
else
    cd "$REPO_DIR"
    git pull origin main
    success "Repository updated"
fi

# ÄÄ Create .env file ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Creating environment file..."
cd "$REPO_DIR"
if [ ! -f ".env" ]; then
    cp .env.example .env
    warn "Please edit .env file with your credentials: nano .env"
fi

# ÄÄ System Optimizations ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Applying system optimizations..."

# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Kernel parameters for production
sudo tee /etc/sysctl.d/99-fusionpact.conf > /dev/null << EOF
# Network optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
vm.swappiness = 10
EOF
sudo sysctl --system

success "System optimizations applied"

# ÄÄ Setup Log Rotation ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
log "Setting up log rotation..."
sudo tee /etc/logrotate.d/docker-containers > /dev/null << EOF
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
success "Log rotation configured"

# ÄÄ Final Output ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
echo ""
echo -e "${GREEN}ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»${NC}"
echo -e "${GREEN}º         ? AWS EC2 Setup Complete!               º${NC}"
echo -e "${GREEN}ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼${NC}"
echo ""
echo -e "  ?? Project Directory: ${CYAN}$REPO_DIR${NC}"
echo -e "  ?? Docker Version:    ${CYAN}$(docker --version)${NC}"
echo -e "  ?? Compose Version:   ${CYAN}$(docker-compose --version)${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. cd $REPO_DIR"
echo "  2. Edit .env file: nano .env"
echo "  3. Run: make up"
echo "  4. Access your services!"
echo ""
echo -e "${YELLOW}??  Note: Log out and back in for Docker group to take effect${NC}"
