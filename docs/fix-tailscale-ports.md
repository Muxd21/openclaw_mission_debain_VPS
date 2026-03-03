# 🔧 Fix: Tailscale Port Connection Issues (3000, 3001, 3003, 2222)

## Problem Summary
You're getting **timeout errors** when accessing ports through Tailscale. This is caused by:
1. socat bridges not forwarding traffic correctly inside PRoot
2. Debian container's network stack not routing to host ports
3. Missing iptables rules for port forwarding

---

## ✅ Quick Fix Commands (Run in Termux)

### Step 1: Kill Existing Bridges & Restart Cleanly
```bash
# Stop all socat processes
pkill socat || true

# Clear any stale socket files
rm -f /tmp/socat-*.sock 2>/dev/null || true
```

### Step 2: Install Required Packages
```bash
pkg install proot-distro wget curl openssh socat iptables netcat-openbsd -y
```

### Step 3: Fix PRoot DNS & Network
```bash
proot-distro login debian -- /root/guest_setup.sh || true

# Inside Debian (after login):
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Add iptables rules for port forwarding
iptables -A FORWARD -i eth0 -p tcp --dport 3000 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3001 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3003 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 2222 -j ACCEPT
iptables-save > /etc/iptables.rules
```

### Step 4: Start socat Bridges with Correct Flags
```bash
# Kill any existing bridges first
pkill socat || true

# Start bridges with Tailscale-aware forwarding
socat TCP4-LISTEN:2222,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:2222 &
socat TCP4-LISTEN:3000,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3000 &
socat TCP4-LISTEN:3001,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3001 &
socat TCP4-LISTEN:3002,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3002 &
socat TCP4-LISTEN:3003,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3003 &

# Verify bridges are running
ps aux | grep socat
```

### Step 5: Start SSHD and Services
```bash
/usr/sbin/sshd
pm2 resurrect || pm2 start all
pm2 save
```

---

## 📋 Complete Diagnostic Script

Copy this into Termux to diagnose issues:

```bash
#!/data/data/com.termux/files/usr/bin/bash

echo "=========================================="
echo "=== Tailscale Port Connection Diagnostics ===="
echo "=========================================="

# Check if PRoot is installed
if proot-distro list 2>/dev/null | grep -q debian; then
    echo "[✓] Debian PRoot is installed"
else
    echo "[✗] Debian PRoot not found. Run: proot-distro install debian"
fi

# Check socat bridges
echo ""
echo "=== Socat Bridge Status ===="
ps aux | grep socat || echo "No socat processes running"

# Check listening ports on host
echo ""
echo "=== Host Listening Ports (Termux) ===="
ss -tlnp 2>/dev/null || netstat -tlnp

# Check if bridges are bound to correct IPs
echo ""
echo "=== Checking Bridge Bind Addresses ===="
for port in 2222 3000 3001 3002 3003; do
    if ss -tlnp | grep -q ":${port} "; then
        echo "[✓] Port $port is listening"
    else
        echo "[✗] Port $port is NOT listening"
    fi
done

# Check inside PRoot
echo ""
echo "=== Entering PRoot to Check Guest Ports ===="
proot-distro login debian -- /bin/bash -c '
echo "--- Inside Debian ---"
ss -tlnp 2>/dev/null || netstat -tlnp
echo ""
echo "--- Checking if services are running ---"
pm2 list 2>/dev/null || echo "PM2 not installed or no apps"
'

# Check Tailscale connectivity
echo ""
echo "=== Tailscale Status ===="
tailscale status --json 2>/dev/null | head -20 || echo "Tailscale not found. Install: pkg install tailscale"

echo ""
echo "=========================================="
echo "=== Diagnostics Complete ===="
echo "=========================================="
```

---

## 🔄 Updated setup.sh (Fixed Version)

Save this as `setup_fixed.sh` in your Termux and run it:

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -e

# --- TERMUX HOST SETUP ---
if [ ! -f "/.dockerenv" ] && [ -z "$PROOT_PID" ]; then
    echo "=========================================="
    echo "==== Starting Fixed Termux Host Setup ===="
    echo "=========================================="
    
    pkg upgrade -y
    pkg install proot-distro wget curl openssh socat iptables netcat-openbsd -y
    
    setup_bridge() {
        pkill socat || true
        socat TCP4-LISTEN:2222,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:2222 &
        socat TCP4-LISTEN:3000,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3000 &
        socat TCP4-LISTEN:3001,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3001 &
        socat TCP4-LISTEN:3002,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3002 &
        socat TCP4-LISTEN:3003,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3003 &
    }
    setup_bridge

    echo "[*] Installing Debian 12 PRoot..."
    if [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
        proot-distro install debian
    else
        echo "[*] Debian is already installed. Continuing..."
    fi
    
    GUEST_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/root"
    mkdir -p "$GUEST_ROOT"
    GUEST_SCRIPT="$GUEST_ROOT/guest_setup.sh"
    
    cat << 'EOF' > "$GUEST_SCRIPT"
#!/bin/bash
set -e
echo "=========================================="
echo "==== Starting Debian 12 Guest Setup   ===="
echo "=========================================="

export DEBIAN_FRONTEND=noninteractive

# Fix DNS resolution for Android PRoot
echo "[*] Fixing DNS resolution..."
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Add iptables rules for port forwarding (persist across reboots)
iptables -F
iptables -A FORWARD -i eth0 -p tcp --dport 2222 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3000 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3001 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3002 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3003 -j ACCEPT
iptables-save > /etc/iptables.rules

# Update and install basic tools
echo "[*] Installing system dependencies..."
apt update && apt upgrade -y
apt install -y curl git nano wget openssh-server build-essential iptables sudo procps ca-certificates netcat-openbsd

# Setup SSH Server in PRoot (VPS Style)
echo "[*] Configuring SSH Server on Port 2222..."
mkdir -p /run/sshd
sed -i 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
# Set a default password 'root'
echo "root:root" | chpasswd

# Install Node.js 22 LTS
echo "[*] Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Install pnpm & pm2 globally
echo "[*] Installing pnpm and pm2..."
npm install -g pnpm pm2 typescript tsx

# Set Global Environment Variables for PRoot stability
echo "export NEXT_TURBO=0" >> /root/.bashrc
echo "export NEXT_TELEMETRY_DISABLED=1" >> /root/.bashrc
echo "export HOST=0.0.0.0" >> /root/.bashrc

REPO_BASE="https://raw.githubusercontent.com/Muxd21/openclaw_mission_debain_VPS/builds"

# Function to attempt Binary Install (Fast)
binary_install() {
    APP_NAME=$1
    echo "[*] Checking for pre-built ${APP_NAME} binary parts..."
    
    if curl --output /dev/null --silent --head --fail "${REPO_BASE}/${APP_NAME}-arm64.tar.gz.part-aa"; then
        echo "[🚀] Prebuilt binary parts found! Downloading..."
        mkdir -p "/root/${APP_NAME}" && cd "/root/${APP_NAME}"
        
        for part in {a..z}{a..z}; do
            PART_FILE="${APP_NAME}-arm64.tar.gz.part-${part}"
            if curl --output /dev/null --silent --head --fail "${REPO_BASE}/${PART_FILE}"; then
                echo "  -> Downloading part ${part}..."
                wget -q "${REPO_BASE}/${PART_FILE}" -O "${PART_FILE}"
            else
                break
            fi
        done
        
        cat ${APP_NAME}-arm64.tar.gz.part-* > "${APP_NAME}.tar.gz"
        rm -rf node_modules .next dist 2>/dev/null || true
        tar -xzf "${APP_NAME}.tar.gz"
        rm "${APP_NAME}.tar.gz" ${APP_NAME}-arm64.tar.gz.part-*
        return 0
    else
        echo "[⚠️] Prebuilt binary not found for ${APP_NAME}. Falling back to slow build..."
        return 1
    fi
}

# --- INSTALL APPS ---
cd /root

# 1. OpenClaw
if ! binary_install "openclaw"; then
    if [ ! -d "openclaw" ]; then git clone --depth 1 https://github.com/openclaw/openclaw.git; fi
    cd openclaw && npm install --legacy-peer-deps && npm run build || true
fi

# 2. Mission Control
cd /root
if ! binary_install "mission-control"; then
    if [ ! -d "mission-control" ]; then git clone --depth 1 https://github.com/builderz-labs/mission-control.git; fi
    cd mission-control && npm install --legacy-peer-deps && npm run build
fi

# 3. Perplexica
cd /root
if ! binary_install "perplexica"; then
    if [ ! -d "perplexica" ]; then git clone --depth 1 https://github.com/ItzCrazyKns/Perplexica.git; fi
    cd perplexica && npm install --legacy-peer-deps && npm run build
fi

# 4. Meilisearch (Required for Perplexica)
echo "[*] Installing Meilisearch..."
apt install -y meilisearch || (wget https://github.com/meilisearch/meilisearch/releases/download/v1.12.1/meilisearch-linux-arm64 -O /usr/local/bin/meilisearch && chmod +x /usr/local/bin/meilisearch)

# --- PRoot Specific Fixes ---
echo "[*] Finalizing configuration..."
sed -i 's/next dev/next dev -H 0.0.0.0/g' /root/mission-control/package.json
sed -i 's/next start/next start -H 0.0.0.0/g' /root/mission-control/package.json

# Setup PM2 for production
echo "[*] Starting services with PM2..."
pm2 delete all 2>/dev/null || true

pm2 start "npm run start -- --port 3000" --name mission-control --cwd /root/mission-control --env HOST=0.0.0.0,NEXT_TURBO=0
pm2 start "npm run gateway -- --port 3001" --name openclaw --cwd /root/openclaw --env HOST=0.0.0.0
cd /root/perplexica
if [ ! -f ".json" ]; then
    echo '{"PORT": 3002, "MEILI_HOST": "http://127.0.0.1:7700"}' > config.json
fi
pm2 start "npm run start:backend" --name px-backend --cwd /root/perplexica
pm2 start "npm run start:frontend" --name px-frontend --cwd /root/perplexica --env PORT=3003

pm2 start "meilisearch --http-addr 127.0.0.1:7700" --name meilisearch

pm2 save

# Create sync script
echo "[*] Creating /root/sync.sh..."
cat << 'SYNC' > /root/sync.sh
#!/bin/bash
echo "=========================================="
echo "==== Starting Perfect Sync & Update   ===="
echo "=========================================="
cd /root/openclaw && git pull && npm install --legacy-peer-deps && npm run build || true
cd /root/mission-control && git pull && npm install --legacy-peer-deps && npm run build
cd /root/perplexica && git pull && npm install --legacy-peer-deps && npm run build
pm2 restart all
pm2 save
echo "==== Sync Complete! ===="
SYNC
chmod +x /root/sync.sh

# Create startup script
echo "[*] Creating /root/start.sh..."
cat << 'STARTUP' > /root/start.sh
#!/bin/bash
/usr/sbin/sshd
pm2 resurrect
iptables-restore < /etc/iptables.rules 2>/dev/null || true
echo "VPS Services Successfully Started."
STARTUP
chmod +x /root/start.sh

echo "==== Debian 12 Guest Setup Complete! ===="
EOF

    chmod +x "$GUEST_SCRIPT"
    
    echo "[*] Entering PRoot to execute guest setup..."
    proot-distro login debian -- /root/guest_setup.sh
    
    echo ""
    echo "=========================================="
    echo "           SETUP IS COMPLETE!             "
    echo "=========================================="
    echo ""
    echo "To enter your Debian 12 VPS anytime simply run:"
    echo "  >> proot-distro login debian"
    echo ""
    echo "To start services upon device reboot, enter Debian and run:"
    echo "  >> /root/start.sh"
    echo ""
    echo "To update both applications (One-Command Sync), enter Debian and run:"
    echo "  >> /root/sync.sh"
    echo ""
    echo "===== CONNECTING VS CODE (VPS STYLE) ====="
    echo "1. Connect your phone to Tailscale."
    echo "2. Connect your PC to Tailscale."
    echo "3. Open VS Code on your PC."
    echo "4. Create a new Remote-SSH connection to:"
    echo "   ssh -p 2222 root@<YOUR_PHONE_TAILSCALE_IP>"
    echo "5. Password is 'root' (change this later using 'passwd' command!)"
    echo ""
    echo "APPS ACCESS THROUGH TAILSCALE:"
    echo "  Mission Control : http://<PHONE>.tail5a917d.ts.net:3000"
    echo "  OpenClaw        : http://<PHONE>.tail5a917d.ts.net:3001"
    echo "  Perplexica      : http://<PHONE>.tail5a917d.ts.net:3003"
    echo "=========================================="
    exit 0
fi

# Already installed - just restart bridges
else
    echo "[*] Debian already installed. Restarting socat bridges..."
    setup_bridge
    echo "[✓] Bridges restarted successfully."
fi