# SuperClaude VPS 🚀

Complete self-hosted Claude Code environment with Telegram control and local AI transcription. Optimized for Hostinger KVM 2 or similar VPS (2 vCPU, 8GB RAM).

## Features

- **🤖 Claude Code CLI** - Full development environment in Docker
- **💬 Telegram Bot** - Control Claude from anywhere
- **🎤 Faster-Whisper** - Optimized local speech-to-text using CTranslate2 (no API costs)
- **🔒 Tailscale** - Secure remote access to dev servers
- **📦 All-in-One** - Single command deployment

## Quick Start (15 minutes)

### Prerequisites

- VPS with Ubuntu 22.04+ (recommended: 2 vCPU, 8GB RAM)
- Telegram Bot token (from [@BotFather](https://t.me/botfather))
- Anthropic API key (or use browser auth)

### 1. Clone and Setup

```bash
# SSH into your VPS
ssh your-user@your-vps-ip

# Clone repository
git clone https://github.com/yourusername/superclaude-vps.git
cd superclaude-vps

# Run automated setup
chmod +x setup.sh
./setup.sh

# Reload shell for aliases
source ~/.bashrc
```

### 2. Configure Environment

```bash
# Copy template and edit
cp .env.template .env
nano .env

# Required fields:
# - ANTHROPIC_API_KEY or use browser auth
# - TELEGRAM_BOT_TOKEN from @BotFather
# - TELEGRAM_USER_ID from @userinfobot
```

### 3. Deploy Everything

```bash
# Build and start Claude environment
docker compose build
docker compose up -d

# Deploy all services (Whisper, Telegram, API Router)
chmod +x deploy-services.sh
./deploy-services.sh

# Verify everything is running
docker ps
pm2 list
```

### 4. Test Your Setup

**Test Claude:**
```bash
sc  # Opens Claude CLI
```

**Test Telegram Bot:**
- Open Telegram
- Find your bot
- Send `/start`
- Try: "Hey Claude, are you there?"
- Send a voice message (auto-transcribed)

**Test Whisper:**
```bash
curl http://localhost:8787/health
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Telegram (Your Phone)                    │
│                  Text / Voice / Images / Files               │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────┐
│                          VPS Server                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Docker Container (claude-dev)              │ │
│  │                                                         │ │
│  │  • Claude CLI    • Bun/Node.js    • MCP Servers       │ │
│  │  • Projects      • Dev tools      • Git               │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │ Whisper API  │  │ Telegram Bot │  │   API Router     │ │
│  │   Port 8787  │  │   PM2/Node   │  │    Port 3850     │ │
│  └──────────────┘  └──────────────┘  └──────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Tailscale (Optional)                   │ │
│  │            Secure access from anywhere                  │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Commands & Aliases

### Claude Control
```bash
sc                  # Start Claude CLI
scshell            # Enter container shell
scstart            # Start container
scstop             # Stop container
sclogs             # View Claude logs
scstatus           # Check container status
```

### Service Management
```bash
botlogs            # View Telegram bot logs
botrestart         # Restart Telegram bot
whisperlogs        # View Whisper API logs
whisperrestart     # Restart Whisper service
```

### System Utilities
```bash
monitor            # System resource monitor (htop)
ports              # Show listening ports
dclean             # Clean Docker resources
tsip               # Show Tailscale IP
tsstatus           # Tailscale connection status
```

## Configuration

### Faster-Whisper Models (CTranslate2 Optimized)

Edit `WHISPER_MODEL` in `.env`:

| Model | Size | Speed (30s audio) | Accuracy | RAM Usage |
|-------|------|-------------------|----------|-----------|
| `tiny` | 75MB | ~1-2 sec | Basic | ~500MB |
| `base` | 150MB | ~2-3 sec | Good | ~1GB |
| `small` | 500MB | ~3-5 sec | Better | ~1.5GB |
| `medium` | 1.5GB | ~5-8 sec | High | ~2GB |
| `large-v3` | 3GB | ~10-15 sec | Best | ~3.5GB |

**Why Faster-Whisper?**
- 4x faster than OpenAI's Whisper
- 2x less memory usage
- CPU-optimized with int8 quantization
- No GPU required

Recommended: `small` for KVM 2, `base` for KVM 1

### Telegram Bot

Your bot supports:
- **Text messages** - Direct chat with Claude
- **Voice messages** - Auto-transcribed via Whisper
- **Images** - Claude vision analysis
- **Files** - Upload to project directory
- **Commands**:
  - `/start` - Initialize bot
  - `/new` - Create new session
  - `/sessions` - List active sessions
  - `/status` - Current session status

### Tailscale Setup (Optional)

For secure remote access:

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect
sudo tailscale up

# Get your IP
tailscale ip -4

# Access services from anywhere
http://your-tailscale-ip:3000  # Dev servers
http://your-tailscale-ip:8787  # Whisper API
```

## Resource Requirements

### Minimum (KVM 1 - $4.99/mo)
- 1 vCPU, 4GB RAM, 50GB Storage
- Works with `tiny`/`base` Whisper models
- 1-2 concurrent Claude sessions
- Basic functionality

### Recommended (KVM 2 - $6.99/mo)
- 2 vCPU, 8GB RAM, 100GB Storage
- Works with `small`/`medium` Whisper models
- 3-5 concurrent Claude sessions
- Full feature set with room to grow

### Performance (KVM 4 - $9.99/mo)
- 4 vCPU, 16GB RAM, 200GB Storage
- Works with `large-v3` Whisper model
- Multiple users/teams
- Production workloads

## Monitoring

### Check System Resources
```bash
monitor            # Interactive (htop)
docker stats       # Container usage
df -h              # Disk usage
free -h            # Memory usage
```

### Service Health
```bash
# Check all services
curl http://localhost:8787/health   # Whisper
curl http://localhost:3850/health   # API Router
pm2 list                            # Telegram Bot
docker ps                           # Claude container
```

### Logs
```bash
# Real-time logs
sclogs             # Claude
whisperlogs        # Whisper transcription
botlogs            # Telegram bot
```

## Troubleshooting

### Claude won't start
```bash
docker compose down
docker compose up -d
docker logs claude-dev
```

### Telegram bot not responding
```bash
pm2 restart telegram-bot
pm2 logs telegram-bot
```

### Whisper slow or failing
```bash
# Check model is downloaded
ls ~/.cache/whisper

# Use smaller model
nano .env  # Change WHISPER_MODEL to 'tiny' or 'base'
sudo systemctl restart whisper-api
```

### High memory usage
```bash
# Clean Docker
docker system prune -a --volumes

# Check swap
free -h

# Restart services
docker compose restart
sudo systemctl restart whisper-api
```

## Security

- ✅ SSH key authentication only
- ✅ UFW firewall configured
- ✅ API keys in environment variables
- ✅ Telegram user whitelist
- ✅ Optional Tailscale for secure access
- ✅ No ports exposed publicly (except SSH)

## Backup

Create regular backups:

```bash
# Backup script included
./scripts/backup.sh

# Manual backup
tar -czf backup.tar.gz ~/.env ~/projects ~/.claude
```

## Cost Analysis

**Monthly costs:**
- VPS (KVM 2): $6.99
- Anthropic API: ~$5-20 (usage based)
- Total: ~$12-27/month

**Savings vs Cloud Services:**
- OpenAI Whisper API: ~$5-10/month saved
- Google Speech-to-Text: ~$15-40/month saved
- AWS Transcribe: ~$20-50/month saved
- Managed hosting: ~$50-200/month saved

**Faster-Whisper Performance:**
- Transcribes 30s audio in 2-5 seconds (small model)
- Runs on CPU - no expensive GPU needed
- CTranslate2 optimization = 4x faster than original Whisper
- Int8 quantization = 50% less RAM usage

## Updates

```bash
# Pull latest changes
git pull

# Rebuild if needed
docker compose build --no-cache
docker compose up -d

# Restart services
./deploy-services.sh
```

## Support

- [Documentation](./docs/)
- [Issues](https://github.com/yourusername/superclaude-vps/issues)
- [Deployment Guide](./docs/VPS-DEPLOYMENT-PLAN.md)

## License

MIT

---

Built for developers who want full control over their AI development environment. 🚀