# SuperClaude + Tailscale Guide

## What is Tailscale?

Tailscale creates a private VPN mesh network between your devices using WireGuard. Each device gets a stable IP (100.x.x.x) that works from anywhere.

**Result:** Your laptop, phone, and VPS can all talk directly to each other as if they were on the same local network.

---

## Setup (One-Time)

### 1. VPS
```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect (follow the auth URL)
sudo tailscale up

# Check your Tailscale IP
tailscale ip -4
# Example output: 100.64.0.2
```

### 2. Your Laptop
```bash
# Mac
brew install tailscale
# Then open Tailscale app and sign in

# Linux
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### 3. Your Phone
- Install Tailscale from App Store / Play Store
- Sign in with same account

### 4. Enable MagicDNS (Optional but Nice)
1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/dns)
2. Enable MagicDNS
3. Now you can use hostnames like `vps` instead of `100.64.0.2`

---

## Daily Usage

### Start SuperClaude
```bash
ssh vps              # or ssh 100.64.0.2
scstart              # Starts container with Tailscale IP detection
```

### Access Your Apps

**From laptop browser:**
```
http://vps:3000      # Your Next.js app (with MagicDNS)
http://100.64.0.2:3000  # Without MagicDNS
```

**From phone browser:**
```
http://100.64.0.2:3000  # Same URL works!
```

**No tunnels. No port forwarding. Just works.**

---

## Expo Mobile Development

This is where Tailscale really shines.

### Start Expo with LAN Mode
```bash
# On VPS
scp MyExpoApp
npx expo start --lan
```

### On Your Phone
1. Open Expo Go app
2. Enter URL manually: `exp://100.64.0.2:8081`
3. Or scan QR code (if it shows correct Tailscale IP)

### Fix QR Code IP (if needed)
```bash
# Set the correct IP for Expo
export REACT_NATIVE_PACKAGER_HOSTNAME=$(tailscale ip -4)
npx expo start --lan

# Or use the helper alias:
expo-start MyExpoApp
```

---

## Testing Matrix

| What | URL | Works From |
|------|-----|------------|
| Next.js / React | `http://vps:3000` | Laptop, Phone, Tablet |
| Expo Web | `http://vps:8081` | Any browser |
| Expo Mobile | `exp://vps:8081` | Expo Go app |
| API Server | `http://vps:4000` | Anywhere on Tailnet |
| Supabase Studio | `http://vps:54321` | Any browser |

---

## SSH Config

Add to `~/.ssh/config` on your laptop:

```
# Use Tailscale IP (works from anywhere)
Host vps
    HostName 100.64.0.2    # Your VPS's Tailscale IP
    User your-username

# Optionally, keep public IP as backup
Host vps-public
    HostName your-vps-public-ip.com
    User your-username
```

Now just: `ssh vps`

---

## Security

### What's Open to Internet?
```bash
# Check firewall
sudo ufw status

# Should show:
# - SSH (22): ALLOW from anywhere (backup access)
# - Everything else: ALLOW only from tailscale0 interface
```

### What's Open to Tailscale?
Everything. But that's only your devices.

### Best Practices
1. **Disable SSH password auth** - use keys only
2. **Consider disabling public SSH** once Tailscale is reliable
3. **Enable Tailscale SSH** for extra security (optional):
   ```bash
   sudo tailscale up --ssh
   # Now SSH goes through Tailscale auth
   ```

---

## Commands Reference

| Command | What it does |
|---------|--------------|
| `tailscale status` | Show connected devices |
| `tailscale ip -4` | Show your Tailscale IP |
| `tailscale ping vps` | Test connectivity |
| `scstatus` | Show Tailscale IP + URLs |
| `scstart` | Start container with IP detection |
| `expo-start MyApp` | Start Expo with correct hostname |

---

## Troubleshooting

### Can't connect to vps:3000

1. **Check Tailscale is running:**
   ```bash
   tailscale status
   ```

2. **Check container is running:**
   ```bash
   ssh vps
   docker ps
   ```

3. **Check app is running:**
   ```bash
   docker exec claude-dev curl localhost:3000
   ```

4. **Check firewall allows Tailscale:**
   ```bash
   sudo ufw status
   # Should show: ALLOW IN on tailscale0
   ```

### Expo QR code shows wrong IP

```bash
# Set correct IP manually
export REACT_NATIVE_PACKAGER_HOSTNAME=$(tailscale ip -4)
npx expo start --lan --clear
```

### Tailscale disconnected

```bash
# Reconnect
sudo tailscale up

# Check status
tailscale status
```

### Phone can't reach VPS

1. Make sure Tailscale is connected on phone
2. Try: `ping 100.64.0.2` from phone terminal (if available)
3. Check Tailscale admin console for both devices

---

## Network Diagram

```
                    ┌─────────────────────────────┐
                    │   Tailscale Coordination    │
                    │   (login.tailscale.com)     │
                    └──────────────┬──────────────┘
                                   │ Auth + Key Exchange
         ┌─────────────────────────┼─────────────────────────┐
         │                         │                         │
         ▼                         ▼                         ▼
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│     Laptop      │      │      VPS        │      │     Phone       │
│   100.64.0.1    │◄────►│   100.64.0.2    │◄────►│   100.64.0.3    │
│                 │      │                 │      │                 │
│  Browser        │      │  Docker         │      │  Expo Go        │
│  VS Code        │      │  ├─ :3000 web   │      │  Safari         │
│  Terminal       │      │  ├─ :8081 expo  │      │                 │
│                 │      │  └─ :4000 api   │      │                 │
└─────────────────┘      └─────────────────┘      └─────────────────┘
         │                         │                         │
         └─────────────────────────┴─────────────────────────┘
                    Direct WireGuard connections
                    (encrypted, peer-to-peer when possible)
```

---

## Tailscale SSH (Advanced)

Replace regular SSH with Tailscale-authenticated SSH:

```bash
# On VPS
sudo tailscale up --ssh

# Now from laptop (no SSH keys needed!)
ssh vps

# Tailscale handles auth via your Tailscale account
```

Benefits:
- No SSH keys to manage
- Auth tied to Tailscale identity
- Can require 2FA via Tailscale
- Audit logs in Tailscale admin

---

## Cost

**Tailscale Personal:** Free for up to 100 devices, 3 users

More than enough for solo dev work.
