# 🚀 OpenClaw & Mission Control: One-Command Termux VPS

This setup converts your Android phone into a powerful Debian 12 VPS using **PRoot-Distro**, pre-configured for **OpenClaw** and **Mission Control**. It is optimized for **Tailscale** and **VS Code Remote-SSH**.

## ⚡ One-Line Quick Install
Run this in **Termux** to install or update everything:

```bash
pkg upgrade -y && pkg install wget -y && wget -qO- https://raw.githubusercontent.com/Muxd21/openclaw_mission_debain_VPS/main/setup.sh | bash
```

## 🛠️ Included Features
- **Auto-Fix PRoot DNS:** No more connectivity issues inside Debian.
- **VPS-Style SSH:** Connect via VS Code on Port `2222` (Password: `root`).
- **NPM-Stabilized:** Uses `npm` instead of `pnpm` for ultra-stable ARM64 builds.
- **Full Network Bridge:** Automatic `socat` bridging ensures Tailscale access to all apps.
- **Production Performance:** Builds and starts in production mode for lower RAM usage.
- **One-Command Sync:** Update all apps from GitHub with `/root/sync.sh`.
- **Perplexica Included:** High-performance AI search engine pre-installed.

## 📂 Project Shortcuts (Inside Debian)
- `Enter Debian`: `proot-distro login debian`
- `Start Services`: `/root/start.sh`
- `Sync & Update`: `/root/sync.sh`
- `Restart Bridges (Termux Host)`: `~/vps-bridge.sh`
- `Mission Control`: `http://<PHONE_IP>:3000`
- `OpenClaw`: `http://<PHONE_IP>:3001`
- `Perplexica`: `http://<PHONE_IP>:3011`

---

## 🌐 Tailscale & Connectivity
This setup is optimized for **Tailscale**. All network bridges are bound to `0.0.0.0` to ensure they are accessible via your Tailscale IP or MagicDNS name.

### Restarting Bridges
If you lose connection to your services after a reboot or network change, run this command in **Termux** (not Debian):
```bash
~/vps-bridge.sh
```

---

## 🤖 GitHub Automation (Auto-Update)
This repo includes a **GitHub Action** that checks for new releases of **Mission Control** and **OpenClaw** 4 times a day. If an update is found, it automatically syncs this setup to ensure the "One-Line Quick Install" always pulls the latest compatible versions.

### Repos Monitored:
1. [builderz-labs/mission-control](https://github.com/builderz-labs/mission-control)
2. [openclaw/openclaw](https://github.com/openclaw/openclaw)
