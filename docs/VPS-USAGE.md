# SuperClaude VPS Quick Reference

## SSH Connection

### Basic (no preview)
```bash
ssh user@your-vps.com
```

### With Port Forwarding (preview apps locally)
```bash
ssh -L 3000:localhost:3000 -L 8081:localhost:8081 -L 4000:localhost:4000 user@your-vps.com
```

### Add to ~/.ssh/config (recommended)
```
Host vps
    HostName your-vps-ip-or-domain.com
    User your-username
    LocalForward 3000 localhost:3000
    LocalForward 3001 localhost:3001
    LocalForward 4000 localhost:4000
    LocalForward 8081 localhost:8081
```
Then just: `ssh vps`

---

## Quick Commands (on VPS)

| Command | What it does |
|---------|--------------|
| `sc` | Launch Claude (YOLO mode) |
| `scp MyProject` | Launch Claude in specific project |
| `scshell` | Open bash in container |
| `scdev` | Open/attach tmux session |
| `scstart` | Start container |
| `scstop` | Stop container |
| `sclogs` | View container logs |

---

## Working on Multiple Projects

### Option 1: Switch Projects
```bash
sc                           # Enter Claude
cd /workspace/projects/ProjectA
# ... work ...
cd /workspace/projects/ProjectB
# ... work ...
```

### Option 2: Multiple tmux Windows
```bash
scdev                        # Start tmux session

# In tmux:
Ctrl+B, C                    # New window
scp ProjectB                 # Start Claude in ProjectB

Ctrl+B, 0                    # Go to window 0
Ctrl+B, 1                    # Go to window 1
Ctrl+B, D                    # Detach (keeps running)
```

### Option 3: Multiple SSH Sessions
```bash
# Terminal 1
ssh vps
scp ProjectA

# Terminal 2
ssh vps
scp ProjectB
```

---

## Testing Apps

### Web App (Next.js, React, etc.)

**On VPS:**
```bash
scp MyWebApp
# Inside Claude or manually:
bun run dev
# Runs on port 3000
```

**On Your Laptop:**
```bash
# If using SSH port forwarding:
open http://localhost:3000

# Or with cloudflare tunnel (for sharing):
ssh vps
cloudflared tunnel --url http://localhost:3000
# Gives you: https://random-words.trycloudflare.com
```

### Expo Mobile App

**Option 1: Tunnel Mode (easiest)**
```bash
scp MyExpoApp
npx expo start --tunnel
# Scan QR code with Expo Go app
```

**Option 2: LAN Mode**
```bash
npx expo start --lan
# Only works if phone is on same network (VPN to VPS)
```

**Option 3: Web Preview**
```bash
npx expo start --web
# Access via localhost:8081 with SSH tunnel
```

### API Testing

```bash
# From inside container
curl http://localhost:4000/api/health

# From laptop (with tunnel)
curl http://localhost:4000/api/users
```

---

## File Syncing

### Clone Projects on VPS
```bash
ssh vps
cd ~/projects
git clone https://github.com/you/myproject.git
```

### Push/Pull Changes
```bash
# On VPS, inside project
git add .
git commit -m "feat: new feature"
git push

# On laptop
git pull
```

### Direct File Editing with VS Code
1. Install "Remote - SSH" extension
2. Connect to VPS
3. Open ~/projects/MyProject
4. Edit files directly
5. VS Code auto-forwards ports!

---

## Tmux Cheat Sheet

| Key | Action |
|-----|--------|
| `Ctrl+B, C` | New window |
| `Ctrl+B, N` | Next window |
| `Ctrl+B, P` | Previous window |
| `Ctrl+B, 0-9` | Go to window N |
| `Ctrl+B, D` | Detach (session keeps running) |
| `Ctrl+B, %` | Split vertical |
| `Ctrl+B, "` | Split horizontal |
| `Ctrl+B, Arrow` | Switch pane |
| `Ctrl+B, X` | Kill pane |

**Reconnect after disconnect:**
```bash
tmux attach -t claude
```

---

## Troubleshooting

### Container won't start
```bash
cd ~/SuperClaude
docker compose logs
docker compose up -d --build
```

### Port already in use
```bash
# Find what's using port 3000
sudo lsof -i :3000
# Kill it or change port
```

### Can't connect to localhost:3000
1. Check SSH tunnel is active
2. Check app is actually running: `docker exec claude-dev curl localhost:3000`
3. Check firewall: `sudo ufw status`

### Expo can't find device
```bash
# Use tunnel mode
npx expo start --tunnel --clear
```

### Claude auth expired
```bash
# If using API key, check .env
cat ~/SuperClaude/.env

# If using OAuth, re-auth:
ssh -L 8080:localhost:8080 vps
docker exec -it claude-dev claude
# Follow browser auth flow
```

---

## Security Reminders

1. **Never expose ports directly** - use SSH tunnels
2. **Use SSH keys**, not passwords
3. **Keep API keys in .env**, not in commands
4. **Firewall**: Only SSH (22) should be open
5. **Regular updates**: `sudo apt update && sudo apt upgrade`
