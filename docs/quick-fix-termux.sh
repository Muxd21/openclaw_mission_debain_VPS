#!/data/data/com.termux/files/usr/bin/bash
# Quick Fix Script for Tailscale Port Connection Issues
# Copy this entire script and paste into Termux, then run: bash docs/quick-fix-termux.sh

set -e

echo "=========================================="
echo "=== OpenClaw VPS - Quick Port Fix ===="
echo "=========================================="

# Step 1: Upgrade packages
echo "[*] Upgrading packages..."
pkg upgrade -y

# Step 2: Install required tools
echo "[*] Installing required tools..."
pkg install proot-distro wget curl openssh socat iptables netcat-openbsd -y

# Step 3: Kill existing bridges
echo "[*] Stopping existing socat bridges..."
pkill socat || true
sleep 1

# Step 4: Start fresh bridges with correct binding
echo "[*] Starting socat bridges on all ports..."
socat TCP4-LISTEN:2222,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:2222 &
socat TCP4-LISTEN:3000,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3000 &
socat TCP4-LISTEN:3001,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3001 &
socat TCP4-LISTEN:3010,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3010 &
socat TCP4-LISTEN:3011,reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:3011 &

echo "[✓] Bridges started successfully"

# Step 5: Verify bridges are listening
echo ""
echo "=== Verifying Port Status ===="
for port in 2222 3000 3001 3010 3011; do
    if ss -tlnp | grep -q ":${port} "; then
        echo "[✓] Port $port is LISTENING"
    else
        echo "[✗] Port $port is NOT listening - restarting..."
        socat TCP4-LISTEN:${port},reuseaddr,fork,bind=0.0.0.0 TCP4:127.0.0.1:${port} &
    fi
done

# Step 6: Enter PRoot and fix guest setup
echo ""
echo "[*] Entering Debian PRoot to apply fixes..."
proot-distro login debian -- /bin/bash -c '
export DEBIAN_FRONTEND=noninteractive

# Fix DNS
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Install iptables if missing
apt install -y iptables >/dev/null 2>&1 || true

# Add persistent iptables rules
iptables -F
iptables -A FORWARD -i eth0 -p tcp --dport 2222 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3000 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3001 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3010 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp --dport 3011 -j ACCEPT

# Save rules
iptables-save > /etc/iptables.rules

echo "[✓] DNS and iptables fixed inside Debian"

# Ensure SSH is running
mkdir -p /run/sshd
/usr/sbin/sshd

# Start services with PM2
pm2 resurrect 2>/dev/null || pm2 start all
pm2 save

echo "[✓] Services started in Debian PRoot"
'

# Step 7: Final verification
echo ""
echo "=== Final Status Check ===="
echo "Host Ports:"
ss -tlnp | grep -E "(2222|3000|3001|3010|3011)" || echo "No ports found"

echo ""
echo "Inside PRoot:"
proot-distro login debian -- /bin/bash -c 'ss -tlnp 2>/dev/null | head -10' || true

# Step 8: Test connectivity
echo ""
echo "=== Testing Connectivity ===="
echo "Testing port 3000 (Mission Control)..."
timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/3000" 2>/dev/null && echo "[✓] Port 3000 is reachable" || echo "[✗] Port 3000 not responding"

echo "Testing port 3001 (OpenClaw)..."
timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/3001" 2>/dev/null && echo "[✓] Port 3001 is reachable" || echo "[✗] Port 3001 not responding"

echo "Testing port 3011 (Perplexica)..."
timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/3011" 2>/dev/null && echo "[✓] Port 3011 is reachable" || echo "[✗] Port 3011 not responding"

echo ""
echo "=========================================="
echo "=== Fix Complete! ===="
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Connect your phone to Tailscale: tailscale up"
echo "2. Connect your PC to Tailscale on another device"
echo "3. Access services via Tailscale DNS:"
echo "   - Mission Control: http://<PHONE>.tail5a917d.ts.net:3000"
echo "   - OpenClaw:       http://<PHONE>.tail5a917d.ts.net:3001"
echo "   - Perplexica:     http://<PHONE>.tail5a917d.ts.net:3011"
echo "   - VS Code SSH:    ssh -p 2222 root@<PHONE>.tail5a917d.ts.net"
echo ""
echo "If ports still timeout, run the diagnostic script:"
echo "  bash docs/diagnose-ports.sh"
echo ""