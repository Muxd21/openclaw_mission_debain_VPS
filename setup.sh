#!/bin/bash
# Perfect One-Command Sync Setup for OpenClaw & Mission Control in Termux Debian 12 PRoot
# Automated Setup Script
# Works over Tailscale with VPS-style VS Code Remote-SSH
# Target Ports: 3000 (Mission Control), 3001 (OpenClaw)

set -e

# --- TERMUX HOST SETUP ---
if [ ! -f "/.dockerenv" ] && [ -z "$PROOT_PID" ] && [ "$(id -u)" != "0" ]; then
    echo "=========================================="
    echo "==== Starting Termux Host Setup ===="
    echo "=========================================="
    
    # Ensure Termux packages are fully upgraded to fix library linkage errors (like curl SSL issues)
    pkg upgrade -y
    
    # Install proot-distro & essential tools
    pkg install proot-distro wget curl openssh -y
    
    # Install Debian 12
    echo "[*] Installing Debian 12 PRoot..."
    if [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
        proot-distro install debian
    else
        echo "[*] Debian is already installed. Continuing..."
    fi
    
    # Create the guest setup script
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
# Update and install basic tools
echo "[*] Installing system dependencies..."
apt update && apt upgrade -y
apt install -y curl git nano wget openssh-server build-essential iptables sudo procps ca-certificates

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
export NEXT_TURBO=0
export NEXT_TELEMETRY_DISABLED=1
export HOST=0.0.0.0

# Install OpenClaw
echo "[*] Setting up OpenClaw..."
cd /root
if [ ! -d "openclaw" ]; then
    git clone https://github.com/openclaw/openclaw.git
fi
cd openclaw
npm install --legacy-peer-deps
echo "[*] Building OpenClaw..."
npm run build || echo "Build error, will attempt runtime start."

# Install Mission Control
echo "[*] Setting up Mission Control..."
cd /root
if [ ! -d "mission-control" ]; then
    git clone https://github.com/builderz-labs/mission-control.git
fi
cd mission-control
npm install --legacy-peer-deps
echo "[*] Building Mission Control..."
npm run build 

# --- PRoot Specific Fixes ---
echo "[*] Patching for PRoot compatibility..."
# Enforce 0.0.0.0 in package scripts
sed -i 's/next dev/next dev -H 0.0.0.0/g' /root/mission-control/package.json
sed -i 's/next start/next start -H 0.0.0.0/g' /root/mission-control/package.json

# Setup PM2 for production (More stable than dev in PRoot)
echo "[*] Starting services with PM2..."
pm2 delete all 2>/dev/null || true

# Mission Control (Port 3000)
cd /root/mission-control
pm2 start "npm run start -- --port 3000" --name mission-control --env HOST=0.0.0.0,NEXT_TURBO=0

# OpenClaw (Port 3001)
cd /root/openclaw
pm2 start "npm run gateway -- --port 3001" --name openclaw --env HOST=0.0.0.0

pm2 save

# Create the Perfect One-Command Sync Script
echo "[*] Creating /root/sync.sh command..."
cat << 'SYNC' > /root/sync.sh
#!/bin/bash
echo "=========================================="
echo "==== Starting Perfect Sync & Update   ===="
echo "=========================================="

# Update System Packages optionally
# apt update && apt upgrade -y

echo "-> Syncing OpenClaw..."
cd /root/openclaw
git pull
npm install --legacy-peer-deps
npm run build || true

echo "-> Syncing Mission Control..."
cd /root/mission-control
git pull
npm install --legacy-peer-deps
npm run build

echo "-> Restarting PM2 Services..."
pm2 restart all
pm2 save
echo "==== Sync Complete! ===="
SYNC
chmod +x /root/sync.sh

# Create Startup Script
echo "[*] Creating /root/start.sh..."
cat << 'STARTUP' > /root/start.sh
#!/bin/bash
# Ensures sshd works and pm2 is resurrected
/usr/sbin/sshd
pm2 resurrect
echo "VPS Services Successfully Started."
STARTUP
chmod +x /root/start.sh

# Finalizing
echo "==== Debian 12 Guest Setup Complete! ===="
EOF
    chmod +x "$GUEST_SCRIPT"
    
    # Execute guest setup script inside PRoot
    echo "[*] Entering PRoot to execute guest setup..."
    proot-distro login debian -- /root/guest_setup.sh
    
    # Done message
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
    echo "APPS ACCESS:"
    echo "  Mission Control : http://<YOUR_PHONE_TAILSCALE_IP>:3000"
    echo "  OpenClaw        : http://<YOUR_PHONE_TAILSCALE_IP>:3001"
    echo "=========================================="
    exit 0
fi
