# Complete VPS Deployment Plan with All Features

## Resource Requirements Analysis

### Component Memory Requirements

| Component | Idle RAM | Active RAM | Storage | CPU Notes |
|-----------|----------|------------|---------|-----------|
| **OS (Ubuntu)** | ~300MB | ~400MB | 10GB | Minimal |
| **Docker + Containers** | ~200MB | ~400MB | 5GB | Minimal |
| **Claude CLI** | ~100MB | ~300MB | 1GB | Light |
| **Telegram Bot** | ~50MB | ~150MB | 100MB | Very light |
| **Whisper API (base)** | ~500MB | ~1GB | 150MB model | CPU intensive |
| **Whisper API (small)** | ~800MB | ~1.5GB | 500MB model | More CPU intensive |
| **Whisper API (large-v3)** | ~2GB | ~3.5GB | 3GB model | Very CPU intensive |
| **Tailscale** | ~30MB | ~50MB | 50MB | Minimal |
| **Project files** | - | - | 10-20GB | - |
| **Docker images** | - | - | 5-10GB | - |
| **Swap (recommended)** | - | - | 2-4GB | - |

## VPS Comparison: KVM 1 vs KVM 2

### KVM 1 ($4.99/mo) - Minimum Viable
```yaml
Resources:
  CPU: 1 vCPU
  RAM: 4 GB
  Storage: 50 GB NVMe
  Bandwidth: 4 TB

What Works:
  ✅ Claude CLI + Docker
  ✅ Telegram Bot
  ✅ Tailscale
  ✅ Whisper (tiny/base models only)
  ✅ 1-2 small projects
  ✅ Basic development

Limitations:
  ⚠️ Whisper transcription will be slow (5-10s for 30s audio)
  ⚠️ Can't run Whisper medium/large models
  ⚠️ Limited to 1-2 active Claude sessions
  ⚠️ May need aggressive Docker cleanup
  ⚠️ No room for databases or additional services

Verdict: Works but tight - requires careful resource management
```

### KVM 2 ($6.99/mo) - Recommended ✨
```yaml
Resources:
  CPU: 2 vCPU
  RAM: 8 GB
  Storage: 100 GB NVMe
  Bandwidth: 8 TB

What Works:
  ✅ Claude CLI + Docker (comfortable)
  ✅ Telegram Bot
  ✅ Tailscale
  ✅ Whisper (up to medium model)
  ✅ 3-5 projects simultaneously
  ✅ Local Supabase for development
  ✅ Multiple Claude sessions
  ✅ Room for experimentation

Advantages:
  ✨ 2x faster Whisper transcription (2-5s for 30s audio)
  ✨ Can run Whisper small/medium for better accuracy
  ✨ Comfortable headroom for development
  ✨ Can add Redis, PostgreSQL, etc.
  ✨ Better multi-tasking with 2 cores
  ✨ Storage for model caching and larger projects

Verdict: Sweet spot for solo development with all features
```

## Full Stack Deployment Guide

### Prerequisites
- Hostinger KVM 2 purchased ($6.99/mo)
- Telegram Bot token from @BotFather
- Your Telegram user ID from @userinfobot
- Anthropic API key (or browser auth)

### Phase 1: Base System Setup (20 min)

```bash
# Initial SSH login
ssh root@your-vps-ip

# Create user
adduser yourusername
usermod -aG sudo yourusername

# Setup SSH keys (from local machine)
ssh-copy-id yourusername@your-vps-ip

# Secure SSH
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart ssh

# Basic firewall
sudo ufw allow OpenSSH
sudo ufw enable
```

### Phase 2: Install Dependencies (15 min)

```bash
# System update
sudo apt update && sudo apt upgrade -y

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Docker Compose
sudo apt install docker-compose-plugin -y

# Development tools
sudo apt install -y git tmux htop ncdu curl wget python3-pip

# Node.js (for Telegram bot)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Bun
curl -fsSL https://bun.sh/install | bash

# Python dependencies for Whisper API
pip3 install uvicorn fastapi faster-whisper httpx python-multipart

# Add swap (important for Whisper)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Phase 3: Tailscale Setup (10 min)

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect (follow auth URL)
sudo tailscale up

# Get your Tailscale IP
tailscale ip -4
# Save this IP! Example: 100.64.0.2

# Enable MagicDNS via web console
# https://login.tailscale.com/admin/dns
```

### Phase 4: SuperClaude Core (15 min)

```bash
cd ~
git clone https://github.com/your-repo/SuperClaude.git
cd SuperClaude

# Create comprehensive .env
cat > .env << 'EOF'
# Core
PROJECTS_ROOT=~/projects
ANTHROPIC_API_KEY=sk-ant-xxx  # Or use browser auth

# Telegram
TELEGRAM_BOT_TOKEN=123456789:ABCdef...
TELEGRAM_ALLOWED_USERS=123456789
TELEGRAM_USER_ID=123456789

# Whisper
WHISPER_MODEL=small  # Good balance for KVM 2
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=int8

# Tailscale
TAILSCALE_IP=100.64.0.2  # Your Tailscale IP

# Performance
ENABLE_EXPERIMENTAL_MCP_CLI=true
EOF

# Build and start
docker compose build
docker compose up -d
```

### Phase 5: Whisper API Setup (10 min)

```bash
# Create Whisper service directory
mkdir -p ~/services/whisper
cd ~/services/whisper

# Copy Whisper API
cp ~/SuperClaude/Additional\ Features/files\ \(4\)/whisper_api.py .

# Create systemd service
sudo tee /etc/systemd/system/whisper-api.service << 'EOF'
[Unit]
Description=SuperClaude Whisper API
After=network.target

[Service]
Type=simple
User=yourusername
WorkingDirectory=/home/yourusername/services/whisper
Environment="WHISPER_MODEL=small"
Environment="MODEL_CACHE_DIR=/home/yourusername/.cache/whisper"
ExecStart=/usr/bin/python3 -m uvicorn whisper_api:app --host 0.0.0.0 --port 8787
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable whisper-api
sudo systemctl start whisper-api

# First run downloads model (takes 2-5 min)
sudo journalctl -u whisper-api -f
```

### Phase 6: Telegram Bot Setup (10 min)

```bash
cd ~/SuperClaude/Additional\ Features/files\ \(4\)

# Install dependencies
npm install

# Create PM2 ecosystem file
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'telegram-bot',
    script: 'bot.ts',
    interpreter: 'tsx',
    env: {
      NODE_ENV: 'production',
      WHISPER_API_URL: 'http://localhost:8787'
    }
  }]
}
EOF

# Install PM2 globally
sudo npm install -g pm2 tsx

# Start bot with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

### Phase 7: API Router & Integration (10 min)

```bash
# Create unified API router
cd ~/services
mkdir api-router
cd api-router

cp ~/SuperClaude/Additional\ Features/files\ \(4\)/api_router.py .

# Create service
sudo tee /etc/systemd/system/api-router.service << 'EOF'
[Unit]
Description=SuperClaude API Router
After=network.target whisper-api.service

[Service]
Type=simple
User=yourusername
WorkingDirectory=/home/yourusername/services/api-router
ExecStart=/usr/bin/python3 -m uvicorn api_router:app --host 0.0.0.0 --port 3850
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable api-router
sudo systemctl start api-router
```

### Phase 8: Claude Hooks Configuration (5 min)

```bash
# Setup hook directory
mkdir -p ~/.superclaude/hooks

# Create notification script
cat > ~/.superclaude/hooks/telegram-notify.sh << 'EOF'
#!/bin/bash
TELEGRAM_USER_ID="123456789"
API_URL="http://localhost:3850"

EVENT_TYPE="$1"
MESSAGE="${2:-Claude needs attention}"

curl -X POST "$API_URL/api/notify" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": $TELEGRAM_USER_ID,
    \"event\": \"$EVENT_TYPE\",
    \"message\": \"$MESSAGE\"
  }"
EOF

chmod +x ~/.superclaude/hooks/telegram-notify.sh

# Add to Claude settings
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "~/.superclaude/hooks/telegram-notify.sh stop"
        }]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "~/.superclaude/hooks/telegram-notify.sh notification"
        }]
      }
    ]
  }
}
EOF
```

### Phase 9: Helper Scripts & Aliases (5 min)

```bash
# Add to ~/.bashrc
cat >> ~/.bashrc << 'EOF'

# SuperClaude
alias sc='docker exec -it claude-dev claude'
alias scshell='docker exec -it claude-dev bash'
alias scstart='cd ~/SuperClaude && docker compose up -d'
alias scstop='cd ~/SuperClaude && docker compose stop'
alias sclogs='docker logs -f claude-dev'

# Telegram bot
alias botlogs='pm2 logs telegram-bot'
alias botrestart='pm2 restart telegram-bot'

# Whisper
alias whisperlogs='sudo journalctl -u whisper-api -f'
alias whisperrestart='sudo systemctl restart whisper-api'

# System
alias ports='sudo lsof -i -P -n | grep LISTEN'
alias dclean='docker system prune -a --volumes'

# Tailscale
alias tsip='tailscale ip -4'
alias tsstatus='tailscale status'

export PROJECTS_ROOT=~/projects
export TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "localhost")
EOF

source ~/.bashrc
```

### Phase 10: Testing Everything (10 min)

```bash
# 1. Test Whisper API
curl http://localhost:8787/health

# 2. Test Telegram Bot
# Open Telegram, message your bot:
# /start
# /projects

# 3. Test Claude
sc
# Authenticate if needed

# 4. Test from Telegram
# Send: "Hey Claude, are you there?"
# Send voice message
# Send image with caption

# 5. Test Tailscale access (from laptop)
curl http://100.64.0.2:8787/health  # Use your Tailscale IP
```

## Resource Monitoring

```bash
# Create monitoring script
cat > ~/monitor.sh << 'EOF'
#!/bin/bash
echo "=== System Resources ==="
free -h
echo ""
df -h /
echo ""
echo "=== Docker Stats ==="
docker stats --no-stream
echo ""
echo "=== Service Status ==="
systemctl is-active whisper-api
pm2 list
echo ""
echo "=== Whisper Model Cache ==="
du -sh ~/.cache/whisper 2>/dev/null || echo "No models cached yet"
EOF

chmod +x ~/monitor.sh
```

## Performance Tuning

### For KVM 1 (4GB RAM)
```bash
# Use tiny Whisper model
WHISPER_MODEL=tiny  # Fast but less accurate

# Aggressive Docker cleanup cron
(crontab -l 2>/dev/null; echo "0 */6 * * * docker system prune -af --volumes") | crontab -

# Limit Claude MCP servers
# Remove unused ones from .mcp.json
```

### For KVM 2 (8GB RAM)
```bash
# Use small or medium Whisper model
WHISPER_MODEL=small  # Good balance
# or
WHISPER_MODEL=medium  # Better accuracy, slower

# Can run additional services
# - Local Supabase
# - Redis cache
# - Multiple Claude sessions
```

## Cost Breakdown

### Monthly Costs
- **KVM 2 VPS**: $6.99
- **Anthropic API**: ~$5-20 (usage based)
- **Tailscale**: Free (personal use)
- **Telegram**: Free
- **Whisper**: Free (self-hosted)
- **Total**: ~$12-27/month

### Compared to Alternatives
- **OpenAI Whisper API**: $0.006/minute (~$5-10/mo saved)
- **Cloud transcription**: $10-30/mo saved
- **Managed hosting**: $50-200/mo saved

## Upgrade Path

### When to go to KVM 4 ($9.99/mo)
- Running large Whisper model (large-v3)
- Multiple team members
- Production workloads
- GPU acceleration needed (via external GPU)

### When to go to KVM 8 ($19.99/mo)
- Full production environment
- Multiple concurrent Whisper streams
- Heavy database usage
- 5+ active developers

## Troubleshooting

### High Memory Usage
```bash
# Check what's using memory
htop

# Restart Whisper with smaller model
sudo systemctl stop whisper-api
# Edit WHISPER_MODEL in service file
sudo systemctl start whisper-api

# Clear Docker
docker system prune -a --volumes
```

### Slow Whisper Transcription
```bash
# Check CPU usage during transcription
htop

# Consider:
# - Smaller model (tiny/base)
# - Reduce beam_size in whisper_api.py
# - Upgrade to KVM 4 for more CPU
```

### Telegram Bot Not Responding
```bash
pm2 logs telegram-bot
pm2 restart telegram-bot
```

## Security Hardening

```bash
# Fail2ban for SSH protection
sudo apt install fail2ban
sudo systemctl enable fail2ban

# Automatic updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades

# Firewall - only allow Tailscale
sudo ufw default deny incoming
sudo ufw allow in on tailscale0
sudo ufw allow OpenSSH
sudo ufw reload
```

## Backup Strategy

```bash
# Weekly backup script
cat > ~/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR=~/backups/$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# Backup configs
cp ~/.env $BACKUP_DIR/
cp -r ~/.claude $BACKUP_DIR/
cp -r ~/SuperClaude/.env $BACKUP_DIR/superclaude.env

# Backup projects
tar -czf $BACKUP_DIR/projects.tar.gz ~/projects

# Backup Whisper models (expensive to redownload)
tar -czf $BACKUP_DIR/whisper-models.tar.gz ~/.cache/whisper

# Keep only last 4 backups
ls -t ~/backups | tail -n +5 | xargs -I {} rm -rf ~/backups/{}
EOF

chmod +x ~/backup.sh
# Add to cron: 0 2 * * 0 ~/backup.sh
```

## Success Metrics

Your setup is working when:
- ✅ Can control Claude from Telegram anywhere
- ✅ Voice messages transcribe in <5 seconds
- ✅ Can access dev servers via Tailscale
- ✅ Notifications arrive when Claude needs input
- ✅ Can switch between multiple projects/sessions
- ✅ System uses <70% RAM under normal load
- ✅ Whisper model is cached (no redownload)

## Summary

**KVM 2 Recommendation**: For just $2 more than KVM 1, you get:
- 2x CPU cores = much faster Whisper
- 2x RAM = run better Whisper models
- 2x Storage = room for growth
- Comfortable headroom for all features

This gives you a fully self-hosted, Telegram-controlled development environment with local AI transcription, accessible from anywhere via Tailscale, for about $12-27/month total.