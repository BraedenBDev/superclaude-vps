#!/bin/bash

# Deploy all SuperClaude services
set -e

# Prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "========================================="
echo "Deploying SuperClaude Services"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check .env exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Copy .env.template to .env and fill in your values"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# 1. Deploy Whisper API
echo -e "\n${YELLOW}Starting Whisper API service...${NC}"
if [ ! -f /etc/systemd/system/whisper-api.service ]; then
    sudo tee /etc/systemd/system/whisper-api.service > /dev/null << EOF
[Unit]
Description=SuperClaude Whisper API
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD/services/whisper
Environment="WHISPER_MODEL=${WHISPER_MODEL:-small}"
Environment="MODEL_CACHE_DIR=${HOME}/.cache/whisper"
Environment="WHISPER_DEVICE=${WHISPER_DEVICE:-cpu}"
Environment="WHISPER_COMPUTE_TYPE=${WHISPER_COMPUTE_TYPE:-int8}"
ExecStart=/usr/bin/python3 -m uvicorn whisper_api:app --host 0.0.0.0 --port 8787
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable whisper-api
fi

sudo systemctl restart whisper-api
echo -e "${GREEN}✓ Whisper API started${NC}"
echo -e "${YELLOW}Note: First run will download the ${WHISPER_MODEL:-small} model (~500MB-3GB)${NC}"
echo -e "${YELLOW}This is a one-time download that will be cached for future use${NC}"

# 2. Deploy API Router
echo -e "\n${YELLOW}Starting API Router service...${NC}"
if [ ! -f /etc/systemd/system/api-router.service ]; then
    sudo tee /etc/systemd/system/api-router.service > /dev/null << EOF
[Unit]
Description=SuperClaude API Router
After=network.target whisper-api.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD/services/api-router
Environment="WHISPER_API_URL=http://localhost:8787"
Environment="TELEGRAM_BOT_URL=http://localhost:3847"
ExecStart=/usr/bin/python3 -m uvicorn api_router:app --host 0.0.0.0 --port 3850
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable api-router
fi

sudo systemctl restart api-router
echo -e "${GREEN}✓ API Router started${NC}"

# 3. Deploy Telegram Bot
echo -e "\n${YELLOW}Starting Telegram Bot...${NC}"
cd services/telegram

# Install dependencies if needed
if [ ! -d node_modules ]; then
    echo "Installing Telegram bot dependencies..."
    npm install
fi

# Create PM2 ecosystem file
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'telegram-bot',
    script: 'bot.ts',
    interpreter: 'tsx',
    env: {
      NODE_ENV: 'production',
      TELEGRAM_BOT_TOKEN: '${TELEGRAM_BOT_TOKEN}',
      TELEGRAM_ALLOWED_USERS: '${TELEGRAM_ALLOWED_USERS}',
      WHISPER_API_URL: 'http://localhost:8787',
      API_ROUTER_URL: 'http://localhost:3850',
      PROJECTS_ROOT: '${PROJECTS_ROOT}'
    }
  }]
}
EOF

# Start with PM2
pm2 stop telegram-bot 2>/dev/null || true
pm2 start ecosystem.config.js
pm2 save
echo -e "${GREEN}✓ Telegram Bot started${NC}"

cd ../..

# 4. Setup Claude hooks
echo -e "\n${YELLOW}Configuring Claude hooks...${NC}"

# Create notification script
cat > ~/.superclaude/hooks/telegram-notify.sh << 'EOF'
#!/bin/bash
TELEGRAM_USER_ID="${TELEGRAM_USER_ID:-$1}"
API_URL="${API_ROUTER_URL:-http://localhost:3850}"

EVENT_TYPE="$1"
MESSAGE="${2:-Claude needs attention}"

curl -X POST "$API_URL/api/notify" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"$TELEGRAM_USER_ID\",
    \"event\": \"$EVENT_TYPE\",
    \"message\": \"$MESSAGE\"
  }" 2>/dev/null || true
EOF

chmod +x ~/.superclaude/hooks/telegram-notify.sh

# Create Claude settings
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "~/.superclaude/hooks/telegram-notify.sh stop 'Claude session stopped'"
        }]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "~/.superclaude/hooks/telegram-notify.sh notification 'Claude needs your attention'"
        }]
      }
    ]
  }
}
EOF

echo -e "${GREEN}✓ Claude hooks configured${NC}"

# 5. Check service status
echo -e "\n${YELLOW}Checking service status...${NC}"
echo -e "\nWhisper API:"
sudo systemctl status whisper-api --no-pager | head -n 3

echo -e "\nAPI Router:"
sudo systemctl status api-router --no-pager | head -n 3

echo -e "\nTelegram Bot:"
pm2 list

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}All services deployed!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\nTest endpoints:"
echo -e "  Whisper: curl http://localhost:8787/health"
echo -e "  Router: curl http://localhost:3850/health"
echo -e "\nTelegram bot:"
echo -e "  Open Telegram and message your bot"
echo -e "  Send /start to begin"
echo -e "\nView logs:"
echo -e "  Whisper: sudo journalctl -u whisper-api -f"
echo -e "  Router: sudo journalctl -u api-router -f"
echo -e "  Bot: pm2 logs telegram-bot"