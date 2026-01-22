#!/bin/bash

# SuperClaude VPS Setup Script
# Automated deployment for Hostinger KVM 2 (or similar VPS)

set -e

# Prevent interactive prompts during package installation
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "========================================="
echo "SuperClaude VPS Setup"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then
   echo -e "${RED}Please run as non-root user with sudo privileges${NC}"
   exit 1
fi

# Function to check command success
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# 1. System Update
echo -e "\n${YELLOW}Step 1: Updating system...${NC}"
sudo apt-get update -qq && sudo apt-get upgrade -y -qq
check_status "System update"

# 2. Install Docker
if ! command -v docker &> /dev/null; then
    echo -e "\n${YELLOW}Step 2: Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    check_status "Docker installation"
    echo -e "${YELLOW}Note: You may need to log out and back in for docker group to take effect${NC}"
else
    echo -e "\n${GREEN}Docker already installed${NC}"
fi

# 3. Install Docker Compose
echo -e "\n${YELLOW}Step 3: Installing Docker Compose...${NC}"
sudo apt-get install -y -qq docker-compose-plugin
check_status "Docker Compose installation"

# 4. Install Development Tools
echo -e "\n${YELLOW}Step 4: Installing development tools...${NC}"
sudo apt-get install -y -qq git tmux htop ncdu curl wget python3-pip
check_status "Development tools"

# 5. Install Node.js
if ! command -v node &> /dev/null; then
    echo -e "\n${YELLOW}Step 5: Installing Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
    check_status "Node.js installation"
else
    echo -e "\n${GREEN}Node.js already installed${NC}"
fi

# 6. Install Bun
if ! command -v bun &> /dev/null; then
    echo -e "\n${YELLOW}Step 6: Installing Bun...${NC}"
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH=$BUN_INSTALL/bin:$PATH
    check_status "Bun installation"
else
    echo -e "\n${GREEN}Bun already installed${NC}"
fi

# 7. Install Python dependencies for Faster-Whisper
echo -e "\n${YELLOW}Step 7: Installing Faster-Whisper (CTranslate2 optimized)...${NC}"
# faster-whisper is 4x faster than OpenAI's whisper with 50% less RAM usage
pip3 install --user --quiet faster-whisper uvicorn fastapi httpx python-multipart
check_status "Faster-Whisper and API dependencies"

# 8. Install PM2
if ! command -v pm2 &> /dev/null; then
    echo -e "\n${YELLOW}Step 8: Installing PM2...${NC}"
    sudo npm install -g pm2 tsx --silent
    check_status "PM2 installation"
else
    echo -e "\n${GREEN}PM2 already installed${NC}"
fi

# 9. Setup Swap (4GB)
if ! swapon --show | grep -q swapfile; then
    echo -e "\n${YELLOW}Step 9: Setting up 4GB swap...${NC}"
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    check_status "Swap setup"
else
    echo -e "\n${GREEN}Swap already configured${NC}"
fi

# 10. Install Tailscale (optional - skipped in automated setup)
echo -e "\n${YELLOW}Step 10: Skipping Tailscale (install manually if needed)${NC}"
# To install Tailscale later, run: curl -fsSL https://tailscale.com/install.sh | sh

# 11. Create project directories
echo -e "\n${YELLOW}Step 11: Creating project directories...${NC}"
mkdir -p ~/projects
mkdir -p ~/.cache/whisper
mkdir -p ~/.superclaude/hooks
check_status "Directory creation"

# 12. Setup environment file
echo -e "\n${YELLOW}Step 12: Creating .env template...${NC}"
if [ ! -f .env ]; then
    cat > .env.template << 'EOF'
# Core Configuration
PROJECTS_ROOT=~/projects

# Anthropic API (optional if using browser auth)
ANTHROPIC_API_KEY=sk-ant-xxx

# Telegram Bot (get from @BotFather)
TELEGRAM_BOT_TOKEN=123456789:ABCdef...
TELEGRAM_ALLOWED_USERS=123456789
TELEGRAM_USER_ID=123456789

# Whisper Configuration
WHISPER_MODEL=small
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=int8
MODEL_CACHE_DIR=~/.cache/whisper

# Performance
ENABLE_EXPERIMENTAL_MCP_CLI=true

# Tailscale (optional)
# TAILSCALE_IP=100.x.x.x
EOF
    echo -e "${GREEN}Created .env.template - Copy to .env and fill in your values${NC}"
else
    echo -e "${GREEN}.env already exists${NC}"
fi

# 13. Add helper aliases
echo -e "\n${YELLOW}Step 13: Adding helper aliases...${NC}"
cat >> ~/.bashrc << 'EOF'

# SuperClaude aliases
alias sc='docker exec -it claude-dev claude'
alias scshell='docker exec -it claude-dev bash'
alias scstart='cd ~/superclaude-vps && docker compose up -d'
alias scstop='cd ~/superclaude-vps && docker compose stop'
alias sclogs='docker logs -f claude-dev'
alias scstatus='docker ps | grep claude'

# Service management
alias botlogs='pm2 logs telegram-bot'
alias botrestart='pm2 restart telegram-bot'
alias whisperlogs='sudo journalctl -u whisper-api -f'
alias whisperrestart='sudo systemctl restart whisper-api'

# System utilities
alias ports='sudo lsof -i -P -n | grep LISTEN'
alias dclean='docker system prune -a --volumes'
alias monitor='htop'

# Tailscale (if installed)
alias tsip='tailscale ip -4 2>/dev/null || echo "Tailscale not connected"'
alias tsstatus='tailscale status 2>/dev/null || echo "Tailscale not installed"'

export PROJECTS_ROOT=~/projects
EOF

echo -e "${GREEN}Aliases added to ~/.bashrc${NC}"

# 14. Setup complete
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nNext steps:"
echo -e "1. Copy .env.template to .env and fill in your values"
echo -e "2. Run: source ~/.bashrc"
echo -e "3. Run: docker compose build"
echo -e "4. Run: docker compose up -d"
echo -e "5. Start services with: ./deploy-services.sh"
echo -e "\nFor Telegram bot setup:"
echo -e "  - Get bot token from @BotFather"
echo -e "  - Get your user ID from @userinfobot"
echo -e "  - Add these to .env file"
echo -e "\nFor Tailscale setup (if installed):"
echo -e "  - Run: sudo tailscale up"
echo -e "  - Follow the auth URL"
echo -e "  - Get your IP: tailscale ip -4"