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
    
    # Install proot-distro, essential tools & socat for bridging
    # Also attempt to install Tailscale; if it fails, the user may need a custom build
    pkg install proot-distro wget curl openssh socat tailscale -y || echo "[⚠️] Tailscale install failed. You can try building from source: https://github.com/anasfanani/tailscale-android-cli"
    
    # Auto-restart bridges on Termux host
    setup_bridge() {
        pkill socat || true
        socat TCP4-LISTEN:2222,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:2222 &
        socat TCP4-LISTEN:3000,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3000 &
        socat TCP4-LISTEN:3001,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3001 &
        socat TCP4-LISTEN:3010,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3010 &
        socat TCP4-LISTEN:3011,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3011 &
    }
    setup_bridge

    # Create persistence script for bridges on Termux host
    cat << 'BRIDGE' > ~/vps-bridge.sh
#!/data/data/com.termux/files/usr/bin/bash
pkill socat || true
socat TCP4-LISTEN:2222,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:2222 &
socat TCP4-LISTEN:3000,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3000 &
socat TCP4-LISTEN:3001,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3001 &
socat TCP4-LISTEN:3010,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3010 &
socat TCP4-LISTEN:3011,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3011 &
echo "Network bridges restarted successfully."
BRIDGE
    chmod +x ~/vps-bridge.sh

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
apt install -y curl git nano wget openssh-server build-essential sudo procps ca-certificates netcat-openbsd

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
echo "export NODE_LLAMA_CPP_SKIP_POSTINSTALL=1" >> /root/.bashrc

# Implement Bionic Bypass for Node.js stability on Android
cat > /root/.node_bypass.js << 'BYPASS'
const os = require('os');
const originalNetworkInterfaces = os.networkInterfaces;
os.networkInterfaces = function() {
  try {
    const interfaces = originalNetworkInterfaces.call(os);
    if (interfaces && Object.keys(interfaces).length > 0) {
      return interfaces;
    }
  } catch (e) {}
  return {
    lo: [{
      address: '127.0.0.1',
      netmask: '255.0.0.0',
      family: 'IPv4',
      mac: '00:00:00:00:00:00',
      internal: true,
      cidr: '127.0.0.1/8'
    }]
  };
};
BYPASS
echo 'export NODE_OPTIONS="--require /root/.node_bypass.js"' >> /root/.bashrc

export NEXT_TURBO=0
export NEXT_TELEMETRY_DISABLED=1
export HOST=0.0.0.0
export NODE_OPTIONS="--require /root/.node_bypass.js"
export NODE_LLAMA_CPP_SKIP_POSTINSTALL=1

# ===== STRIP LLAMA.CPP FUNCTION =====
# Nuclear removal of node-llama-cpp from any project (including pnpm monorepos).
# Handles onlyBuiltDependencies vs neverBuiltDependencies conflict.
strip_llama_cpp() {
    local PROJECT_DIR="$1"
    echo "[🔧] Stripping node-llama-cpp from ${PROJECT_DIR}..."

    # 1. Remove node-llama-cpp from ALL package.json files (root + all workspace packages)
    find "${PROJECT_DIR}" -name "package.json" -not -path "*/node_modules/*" | while read pkgfile; do
        node -e "
            const fs = require('fs');
            const pkg = JSON.parse(fs.readFileSync('$pkgfile', 'utf8'));
            let changed = false;
            for (const s of ['dependencies','devDependencies','optionalDependencies','peerDependencies']) {
                if (pkg[s] && pkg[s]['node-llama-cpp']) { delete pkg[s]['node-llama-cpp']; changed = true; }
            }
            if (changed) {
                fs.writeFileSync('$pkgfile', JSON.stringify(pkg, null, 2) + '\\n');
                console.log('  [✔] Stripped from: $pkgfile');
            }
        " 2>/dev/null || true
    done

    # 2. Handle pnpm build config (detect whitelist vs blacklist mode)
    if [ -f "${PROJECT_DIR}/package.json" ]; then
        node -e "
            const fs = require('fs');
            const pkgPath = '${PROJECT_DIR}/package.json';
            const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
            if (!pkg.pnpm) pkg.pnpm = {};
            // If onlyBuiltDependencies exists (whitelist), remove llama from it
            if (pkg.pnpm.onlyBuiltDependencies) {
                pkg.pnpm.onlyBuiltDependencies = pkg.pnpm.onlyBuiltDependencies.filter(d => d !== 'node-llama-cpp');
                console.log('  [✔] Removed from onlyBuiltDependencies whitelist');
            } else {
                // No whitelist, safe to use blacklist
                if (!pkg.pnpm.neverBuiltDependencies) pkg.pnpm.neverBuiltDependencies = [];
                if (!pkg.pnpm.neverBuiltDependencies.includes('node-llama-cpp')) {
                    pkg.pnpm.neverBuiltDependencies.push('node-llama-cpp');
                }
                console.log('  [✔] Added to neverBuiltDependencies blacklist');
            }
            // Override to local stub
            if (!pkg.pnpm.overrides) pkg.pnpm.overrides = {};
            pkg.pnpm.overrides['node-llama-cpp'] = 'link:./llama-stub';
            if (!pkg.overrides) pkg.overrides = {};
            pkg.overrides['node-llama-cpp'] = 'link:./llama-stub';
            fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\\n');
            console.log('  [✔] Injected pnpm config + overrides');
        " 2>/dev/null || true
    fi

    # 3. Create a tiny stub package for the override to resolve to
    mkdir -p "${PROJECT_DIR}/llama-stub"
    echo '{"name":"node-llama-cpp","version":"0.0.0","description":"stub"}' > "${PROJECT_DIR}/llama-stub/package.json"
    echo 'module.exports = {};' > "${PROJECT_DIR}/llama-stub/index.js"

    # 4. Clean pnpm-lock.yaml of any llama references
    if [ -f "${PROJECT_DIR}/pnpm-lock.yaml" ]; then
        sed -i '/node-llama-cpp/d' "${PROJECT_DIR}/pnpm-lock.yaml" 2>/dev/null || true
        echo "  [✔] Cleaned pnpm-lock.yaml"
    fi

    # 5. Create .npmrc to block scripts for node-llama-cpp
    echo 'node-llama-cpp:ignore-scripts=true' >> "${PROJECT_DIR}/.npmrc"

    # 6. Delete any existing node-llama-cpp installations
    rm -rf "${PROJECT_DIR}/node_modules/node-llama-cpp" 2>/dev/null || true
    rm -rf "${PROJECT_DIR}/node_modules/.pnpm/node-llama-cpp"* 2>/dev/null || true
    find "${PROJECT_DIR}" -path "*/node_modules/node-llama-cpp" -type d -exec rm -rf {} + 2>/dev/null || true

    echo "  ✔ node-llama-cpp fully stripped from ${PROJECT_DIR}"
}

REPO_BASE="https://raw.githubusercontent.com/Muxd21/openclaw_mission_debain_VPS/builds"

# Function to attempt Binary Install (Fast)
binary_install() {
    APP_NAME=$1
    echo "[*] Checking for pre-built ${APP_NAME} binary parts..."
    
    # Check if at least the first part exists
    if curl --output /dev/null --silent --head --fail "${REPO_BASE}/${APP_NAME}-arm64.tar.gz.part-aa"; then
        echo "[🚀] Prebuilt binary parts found! Downloading..."
        mkdir -p "/root/${APP_NAME}" && cd "/root/${APP_NAME}"
        
        # Download all parts (aa, ab, ac...)
        for part in {a..z}{a..z}; do
            PART_FILE="${APP_NAME}-arm64.tar.gz.part-${part}"
            if curl --output /dev/null --silent --head --fail "${REPO_BASE}/${PART_FILE}"; then
                echo "  -> Downloading part ${part}..."
                wget -q "${REPO_BASE}/${PART_FILE}" -O "${PART_FILE}"
            else
                break # No more parts
            fi
        done
        
        # Reconstruct and extract
        echo "[*] Reconstructing archive..."
        cat ${APP_NAME}-arm64.tar.gz.part-* > "${APP_NAME}.tar.gz"
        # CLEAN-UP BEFORE EXTRACT TO AVOID SYMLINK ERRORS
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
    strip_llama_cpp /root/openclaw
    cd openclaw && npm install --legacy-peer-deps --ignore-scripts=false && npm run build || true
    # Remove llama artifacts that may have been pulled in post-install
    rm -rf /root/openclaw/node_modules/node-llama-cpp 2>/dev/null || true
fi

# 2. Mission Control
cd /root
if ! binary_install "mission-control"; then
    if [ ! -d "mission-control" ]; then git clone --depth 1 https://github.com/builderz-labs/mission-control.git; fi
    strip_llama_cpp /root/mission-control
    cd mission-control && npm install --legacy-peer-deps && npm run build
fi

# 3. Perplexica
cd /root
if ! binary_install "perplexica"; then
    if [ ! -d "perplexica" ]; then git clone --depth 1 https://github.com/ItzCrazyKns/Perplexica.git; fi
    strip_llama_cpp /root/perplexica
    cd perplexica && npm install --legacy-peer-deps && npm run build
fi

# 4. Meilisearch (Required for Perplexica)
echo "[*] Installing Meilisearch..."
apt install -y meilisearch || (wget https://github.com/meilisearch/meilisearch/releases/download/v1.12.1/meilisearch-linux-arm64 -O /usr/local/bin/meilisearch && chmod +x /usr/local/bin/meilisearch)

# --- PRoot Specific Fixes ---
echo "[*] Finalizing configuration..."
# Always ensure binding 0.0.0.0 is enforced in package.json
sed -i 's/next dev/next dev -H 0.0.0.0/g' /root/mission-control/package.json
sed -i 's/next start/next start -H 0.0.0.0/g' /root/mission-control/package.json

# Setup PM2 for production (More stable than dev in PRoot)
echo "[*] Starting services with PM2..."
pm2 delete all 2>/dev/null || true

# Mission Control (Port 3000)
pm2 start "npm run start -- --port 3000" --name mission-control --cwd /root/mission-control --env HOST=0.0.0.0,NEXT_TURBO=0

# OpenClaw (Port 3001)
pm2 start "npm run gateway -- --port 3001" --name openclaw --cwd /root/openclaw --env HOST=0.0.0.0

# Perplexica Backend (Port 3010) & Frontend (Port 3011)
cd /root/perplexica
if [ ! -f "config.json" ]; then
    echo '{"PORT": 3010, "MEILI_HOST": "http://127.0.0.1:7700"}' > config.json
fi
pm2 start "npm run start:backend" --name px-backend --cwd /root/perplexica
pm2 start "npm run start:frontend" --name px-frontend --cwd /root/perplexica --env PORT=3011

# Meilisearch
pm2 start "meilisearch --http-addr 127.0.0.1:7700" --name meilisearch

pm2 save

# Create the Perfect One-Command Sync Script
echo "[*] Creating /root/sync.sh command..."
cat << 'SYNC' > /root/sync.sh
#!/bin/bash
set -e
export NODE_LLAMA_CPP_SKIP_POSTINSTALL=1
echo "=========================================="
echo "==== Starting Perfect Sync & Update   ===="
echo "=========================================="

# Nuclear removal of node-llama-cpp (handles monorepos + onlyBuiltDependencies conflicts)
strip_llama_cpp() {
    local PROJECT_DIR="$1"
    # Strip from ALL package.json files (root + workspaces)
    find "${PROJECT_DIR}" -name "package.json" -not -path "*/node_modules/*" | while read pkgfile; do
        node -e "
            const fs = require('fs');
            const pkg = JSON.parse(fs.readFileSync('$pkgfile', 'utf8'));
            let c = false;
            for (const s of ['dependencies','devDependencies','optionalDependencies','peerDependencies']) {
                if (pkg[s] && pkg[s]['node-llama-cpp']) { delete pkg[s]['node-llama-cpp']; c = true; }
            }
            if (c) fs.writeFileSync('$pkgfile', JSON.stringify(pkg, null, 2) + '\\n');
        " 2>/dev/null || true
    done
    # Handle pnpm config (detect whitelist vs blacklist)
    node -e "
        const fs = require('fs');
        const p = '${PROJECT_DIR}/package.json';
        const pkg = JSON.parse(fs.readFileSync(p, 'utf8'));
        if (!pkg.pnpm) pkg.pnpm = {};
        if (pkg.pnpm.onlyBuiltDependencies) {
            pkg.pnpm.onlyBuiltDependencies = pkg.pnpm.onlyBuiltDependencies.filter(d => d !== 'node-llama-cpp');
        } else {
            if (!pkg.pnpm.neverBuiltDependencies) pkg.pnpm.neverBuiltDependencies = [];
            if (!pkg.pnpm.neverBuiltDependencies.includes('node-llama-cpp')) pkg.pnpm.neverBuiltDependencies.push('node-llama-cpp');
        }
        if (!pkg.pnpm.overrides) pkg.pnpm.overrides = {};
        pkg.pnpm.overrides['node-llama-cpp'] = 'link:./llama-stub';
        fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + '\\n');
    " 2>/dev/null || true
    # Create stub package
    mkdir -p "${PROJECT_DIR}/llama-stub"
    echo '{"name":"node-llama-cpp","version":"0.0.0"}' > "${PROJECT_DIR}/llama-stub/package.json"
    echo 'module.exports = {};' > "${PROJECT_DIR}/llama-stub/index.js"
    # Clean lockfile + nuke installed dirs
    sed -i '/node-llama-cpp/d' "${PROJECT_DIR}/pnpm-lock.yaml" 2>/dev/null || true
    echo 'node-llama-cpp:ignore-scripts=true' >> "${PROJECT_DIR}/.npmrc" 2>/dev/null || true
    rm -rf "${PROJECT_DIR}/node_modules/node-llama-cpp" 2>/dev/null || true
    rm -rf "${PROJECT_DIR}/node_modules/.pnpm/node-llama-cpp"* 2>/dev/null || true
    find "${PROJECT_DIR}" -path "*/node_modules/node-llama-cpp" -type d -exec rm -rf {} + 2>/dev/null || true
}

# Update System Packages optionally
# apt update && apt upgrade -y

echo "-> Syncing OpenClaw..."
cd /root/openclaw
git stash 2>/dev/null || true
git pull
strip_llama_cpp /root/openclaw
npm install --legacy-peer-deps
npm run build || true
rm -rf /root/openclaw/node_modules/node-llama-cpp 2>/dev/null || true

echo "-> Syncing Mission Control..."
cd /root/mission-control
git stash 2>/dev/null || true
git pull
strip_llama_cpp /root/mission-control
npm install --legacy-peer-deps
npm run build

echo "-> Syncing Perplexica..."
cd /root/perplexica
git stash 2>/dev/null || true
git pull
strip_llama_cpp /root/perplexica
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
echo "NOTE: If you cannot connect, run 'setup_bridge' in your Termux Host."
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
    echo "  Perplexica      : http://<YOUR_PHONE_TAILSCALE_IP>:3011"
    echo "=========================================="
    exit 0
fi
