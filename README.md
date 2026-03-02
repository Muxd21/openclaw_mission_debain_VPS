# OpenClaw & Mission Control Debian 12 VPS Setup for Termux

This repository contains an automated script to convert a mobile device running Termux into a full-fledged VPS environment using `proot-distro` with Debian 12. It sets up and optimally configures:

- **[OpenClaw](https://github.com/openclaw/openclaw)** (Running on Port 3001)
- **[Mission Control](https://github.com/builderz-labs/mission-control)** (Running on Port 3000)

## Features

- **Automated Installation:** Installs dependencies (`proot`, `wget`, `ssh`, `tailscale`), sets up Debian 12, Node.js 22 LTS, `pnpm`, and `pm2`.
- **Background Processes:** Uses PM2 to manage both applications seamlessly.
- **SSH Connectivity:** Launches an SSH Server inside Debian on port `2222` to connect using VS Code via your PC just like a real VPS.
- **One-Command Sync:** Keeps OpenClaw and Mission Control safely updated with a `sync.sh` available inside the environment.
- **Tailscale Optimization:** Use Tailscale on Termux/Mobile to access OpenClaw and Mission Control via Tailscale IP directly from your PC!

---

## 🚀 Quick Setup Instructions

1. **Install Termux** from F-Droid (do not use Google Play version).
2. Inside Termux, clone this repository or download the setup script:
   ```bash
   pkg update && pkg install git -y
   git clone https://github.com/Muxd21/openclaw_mission_debain_VPS.git
   cd openclaw_mission_debain_VPS
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Grab a Coffee!** The script will handle the heavy lifting of installing Debian 12, downloading Node, and building both applications locally.

---

## 💻 Connecting from your PC (VS Code Remote)

You can write plugins and configurations locally on your mobile using VS Code from your Desktop PC.

1. Ensure **Tailscale** is installed and active on both your mobile device (Host) and your PC.
2. In VS Code on your PC, install the **Remote - SSH** extension.
3. Add a new SSH Host:
   ```
   ssh -p 2222 root@<YOUR_PHONE_TAILSCALE_IP>
   ```
4. By default, the Root password is set to: `root` (Make sure to change this using `passwd`!).
5. Once inside, you have a completely isolated standard Linux workspace under `/root`.

---

## 🔄 Updating Applications

To update both OpenClaw and Mission Control automatically in the future, login to your Debian instance and run the sync script:

```bash
# 1. Login to your Debian VPS
proot-distro login debian

# 2. Run the Perfect Sync command
/root/sync.sh
```

---

## 📱 Access the Web Platforms

Once everything is up, use Tailscale IP from your PC's browser:
- **Mission Control Admin**: `http://<YOUR_PHONE_TAILSCALE_IP>:3000` (Default Pass/User: admin/admin)
- **OpenClaw Gateway**: `http://<YOUR_PHONE_TAILSCALE_IP>:3001`
