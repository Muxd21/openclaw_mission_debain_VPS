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
- **NPM-Stabilized:** Uses `npm` instead of `pnpm` to bypass PRoot symlink errors.
- **Production Performance:** Runs in production mode for lower RAM usage and better stability.
- **One-Command Sync:** Update both apps from GitHub with `/root/sync.sh`.

## 📂 Project Shortcuts (Inside Debian)
- `Enter Debian`: `proot-distro login debian`
- `Start Services`: `/root/start.sh`
- `Sync & Update`: `/root/sync.sh`
- `Mission Control`: `http://<PHONE_IP>:3000`
- `OpenClaw`: `http://<PHONE_IP>:3001`

---

## 🤖 GitHub Automation (Auto-Update)
This repo includes a **GitHub Action** that checks for new releases of **Mission Control** and **OpenClaw** 4 times a day. If an update is found, it automatically syncs this setup to ensure the "One-Line Quick Install" always pulls the latest compatible versions.

### Repos Monitored:
1. [builderz-labs/mission-control](https://github.com/builderz-labs/mission-control)
2. [openclaw/openclaw](https://github.com/openclaw/openclaw)
