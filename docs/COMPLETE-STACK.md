# SuperClaude Complete Stack

**Fully self-hosted Claude Code control from Telegram with local speech-to-text.**

No external API dependencies (except Anthropic for Claude itself).

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Your Phone (Telegram)                                                        │
│                                                                               │
│  Text ─────────────────────────────────────────────────────┐                 │
│  Voice 🎤 ─────────────────────────────────────────────────┤                 │
│  Image 📷 ─────────────────────────────────────────────────┤                 │
│                                                             │                 │
└─────────────────────────────────────────────────────────────┼─────────────────┘
                                                              │
                                                              ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  VPS (Tailscale)                                                              │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │  API Router (:3850)                                                     │  │
│  │  └─ /api/transcribe  →  Whisper                                        │  │
│  │  └─ /api/notify      →  Telegram Bot                                   │  │
│  │  └─ /api/health      →  All services                                   │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│           │                           │                                       │
│           ▼                           ▼                                       │
│  ┌─────────────────────┐    ┌─────────────────────┐                          │
│  │  Whisper (:8787)    │    │  Telegram Bot       │                          │
│  │  - faster-whisper   │    │  - Sessions         │                          │
│  │  - CPU optimized    │    │  - Voice/Image      │                          │
│  │  - No external API  │    │  - Notifications    │                          │
│  └─────────────────────┘    └──────────┬──────────┘                          │
│                                        │                                      │
│                                        ▼                                      │
│                             ┌─────────────────────┐                          │
│                             │  Claude Code        │                          │
│                             │  - Your projects    │                          │
│                             │  - MCP servers      │                          │
│                             │  - Dev servers      │                          │
│                             └─────────────────────┘                          │
│                                                                               │
│  Hooks ──────────────────────────────────────────────────────────────────────┤
│  (Claude → API → Telegram → Your phone)                                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Features

| Feature | How It Works |
|---------|--------------|
| **Text chat** | Send message → Claude |
| **Voice messages** | Voice → Local Whisper → Text → Claude |
| **Images** | Photo → Claude vision |
| **File uploads** | Document → Project directory → Claude |
| **Multiple sessions** | Per project/worktree |
| **Session switching** | Tap to switch context |
| **Notifications** | Claude hooks → Telegram |

---

## Quick Start

### 1. Create Telegram Bot (2 min)

```
1. Message @BotFather on Telegram
2. Send /newbot
3. Copy the bot token
```

### 2. Get Your User ID (1 min)

```
1. Message @userinfobot on Telegram
2. Copy your user ID
```

### 3. Configure (2 min)

```bash
cd ~/SuperClaude

cat > .env << EOF
# Projects
PROJECTS_ROOT=~/projects

# Anthropic (for Claude)
ANTHROPIC_API_KEY=sk-ant-...

# Telegram
TELEGRAM_BOT_TOKEN=123456789:ABCdef...
TELEGRAM_ALLOWED_USERS=123456789
TELEGRAM_USER_ID=123456789

# Whisper model (tiny/base/small/medium/large-v3)
WHISPER_MODEL=base
WHISPER_MEMORY=2G
EOF
```

### 4. Start (5 min first time - downloads Whisper model)

```bash
docker compose -f docker-compose.complete.yml up -d

# Watch logs
docker compose -f docker-compose.complete.yml logs -f
```

### 5. Test

```bash
# Check all services
curl http://localhost:3850/api/health

# Test Whisper
curl -X POST http://localhost:3850/api/transcribe \
  -F "file=@test.mp3"
```

### 6. Chat with your bot!

Open Telegram → Find your bot → `/start`

---

## Services

| Service | Port | Purpose |
|---------|------|---------|
| `claude-dev` | 3000, 8081, etc. | Claude Code + dev servers |
| `whisper` | 8787 (internal) | Speech-to-text |
| `telegram-bot` | 3847 (internal) | Telegram interface |
| `api` | 3850 | Unified API gateway |

---

## Whisper Models

| Model | Size | RAM | Speed | Use Case |
|-------|------|-----|-------|----------|
| `tiny` | 75MB | 1GB | ⚡⚡⚡⚡ | Quick tests |
| `base` | 150MB | 1GB | ⚡⚡⚡ | **Default - good balance** |
| `small` | 500MB | 2GB | ⚡⚡ | Better accuracy |
| `medium` | 1.5GB | 4GB | ⚡ | High accuracy |
| `large-v3` | 3GB | 8GB | 🐢 | Best accuracy |

Change model:
```bash
# In .env
WHISPER_MODEL=small
WHISPER_MEMORY=3G

# Restart
docker compose -f docker-compose.complete.yml up -d whisper
```

---

## API Endpoints

### Transcription

```bash
# Upload file
curl -X POST http://localhost:3850/api/transcribe \
  -F "file=@voice.ogg"

# From URL (for Telegram files)
curl -X POST http://localhost:3850/api/transcribe/url \
  -H "Content-Type: application/json" \
  -d '{"url": "https://..."}'

# OpenAI-compatible (drop-in replacement)
curl -X POST http://localhost:3850/api/v1/audio/transcriptions \
  -F "file=@audio.mp3" \
  -F "model=whisper-1"
```

### Notifications

```bash
# From Claude hooks
curl -X POST http://localhost:3850/api/notify \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 123456789,
    "sessionId": "myproject",
    "event": "stop",
    "message": "Task completed"
  }'

# Simple (for scripts)
curl -X POST "http://localhost:3850/api/notify/simple?user_id=123&message=Done"
```

### Health

```bash
curl http://localhost:3850/api/health
```

---

## Telegram Commands

| Command | Description |
|---------|-------------|
| `/start` | Welcome + help |
| `/new` | Create session |
| `/projects` | List projects |
| `/sessions` | List active sessions |
| `/switch` | Switch session |
| `/status` | Current session info |
| `/last` | Last Claude message |
| `/stop` | End session |

---

## Voice Message Demo

```
You:     🎤 "Hey Claude, can you add form validation 
            to the login component?"

Bot:     🎤 Transcribed: "Hey Claude, can you add form 
            validation to the login component?"
         🔄 Sending to Claude...

Bot:     ✅ Done! I've added validation to LoginForm.tsx:
         - Email format validation
         - Password minimum length
         - Error message display
         ...
```

---

## Notification Flow

```
Claude finishes task
        │
        ▼
Hook: notify-local.sh stop
        │
        ▼
curl → API Router (:3850)
        │
        ▼
Telegram Bot → Your Phone
        │
        ▼
┌────────────────────────────────┐
│ ✅ STOP                        │
│                                │
│ Session: myproject-abc123      │
│ ✅ Task completed in myproject │
│                                │
│ [📋 Status] [🔄 Switch]       │
└────────────────────────────────┘
```

---

## Directory Structure

```
~/SuperClaude/
├── docker-compose.complete.yml  # All services
├── .env                         # Configuration
├── Dockerfile                   # Claude container
│
├── telegram-bot/
│   ├── bot.ts                   # Telegram bot
│   ├── Dockerfile
│   └── package.json
│
├── whisper-api/
│   ├── whisper_api.py           # Whisper FastAPI
│   ├── Dockerfile
│   └── requirements.txt
│
├── api-router/
│   ├── api_router.py            # Unified gateway
│   └── Dockerfile
│
├── hooks/
│   └── notify-local.sh          # Notification hook
│
└── templates/
    ├── CLAUDE.md
    ├── settings.json            # Hook config
    └── ...
```

---

## Resource Requirements

| Service | CPU | RAM | Disk |
|---------|-----|-----|------|
| Claude | 1 core | 1GB | - |
| Whisper (base) | 1 core | 1GB | 200MB |
| Whisper (small) | 2 cores | 2GB | 600MB |
| Whisper (large) | 4 cores | 8GB | 4GB |
| Telegram Bot | 0.5 core | 256MB | - |
| API Router | 0.5 core | 128MB | - |

**Minimum VPS:** 2 vCPU, 4GB RAM (with base model)
**Recommended:** 4 vCPU, 8GB RAM (with small/medium model)

---

## Troubleshooting

### Whisper model download slow

First start downloads the model (~150MB for base). Be patient or pre-pull:

```bash
docker compose -f docker-compose.complete.yml build --build-arg PRELOAD_MODEL=true whisper
```

### Voice transcription fails

```bash
# Check Whisper is running
curl http://localhost:8787/health

# Check logs
docker logs superclaude-whisper
```

### Notifications not arriving

```bash
# Test notification endpoint
curl -X POST http://localhost:3850/api/notify \
  -H "Content-Type: application/json" \
  -d '{"userId": YOUR_ID, "sessionId": "test", "event": "stop", "message": "Test"}'

# Check bot logs
docker logs superclaude-telegram-bot
```

### Out of memory

Reduce Whisper model size:
```bash
WHISPER_MODEL=tiny  # In .env
```

---

## Security Notes

1. **User whitelist**: Only users in `TELEGRAM_ALLOWED_USERS` can use the bot
2. **Internal network**: Whisper and bot only accessible via API router
3. **No external APIs**: Everything except Anthropic runs locally
4. **Tailscale**: Access everything securely from anywhere

---

## Costs

| Item | Cost |
|------|------|
| Anthropic API | Pay per use |
| VPS (4GB) | ~$10-20/month |
| Telegram | Free |
| Whisper | Free (local) |
| OpenAI | **$0** (not needed!) |

---

## Files to Copy

1. `docker-compose.complete.yml` → Main compose file
2. `whisper-api/*` → Whisper service
3. `telegram-bot/*` → Bot service  
4. `api-router/*` → API gateway
5. `hooks/notify-local.sh` → Notification hook
6. `templates/settings.json` → Hook configuration

---

## Next Steps

1. Copy all files to your VPS
2. Create `.env` with your tokens
3. `docker compose -f docker-compose.complete.yml up -d`
4. Message your bot on Telegram
5. Code from anywhere! 🚀
