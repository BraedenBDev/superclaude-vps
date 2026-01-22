# Quick Deployment Instructions

## 1. Push to GitHub

From your local machine:

```bash
cd superclaude-vps
git remote add origin https://github.com/YOUR_USERNAME/superclaude-vps.git
git commit -m "Initial commit: SuperClaude VPS setup"
git branch -M main
git push -u origin main
```

## 2. Deploy on VPS

SSH into your Hostinger KVM 2:

```bash
# Connect to VPS
ssh your-user@your-vps-ip

# Clone repository
git clone https://github.com/YOUR_USERNAME/superclaude-vps.git
cd superclaude-vps

# Run setup (installs everything)
chmod +x setup.sh
./setup.sh

# Configure environment
cp .env.template .env
nano .env  # Add your API keys

# Build and start
docker compose build
docker compose up -d

# Deploy services
chmod +x deploy-services.sh
./deploy-services.sh

# Test
curl http://localhost:8787/health
```

## 3. Test Telegram Bot

1. Open Telegram
2. Find your bot
3. Send `/start`
4. Try voice message or text

## Total time: ~20 minutes

Everything is automated - just follow the prompts!