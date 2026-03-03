#!/data/data/com.termux/files/usr/bin/bash
# Diagnostic Script for Port Connection Issues
# Run this in Termux to diagnose why ports aren't accessible

echo "=========================================="
echo "=== OpenClaw VPS - Port Diagnostics ===="
echo "=========================================="

# Check 1: PRoot Installation Status
echo ""
echo "[CHECK 1] Debian PRoot Installation"
if proot-distro list 2>/dev/null | grep -q debian; then
    echo "[✓] Debian PRoot is installed"
else
    echo "[✗] ERROR: Debian PRoot not found!"
    echo "   Run: proot-distro install debian"
fi

# Check 2: Socat Bridge Status
echo ""
echo "[CHECK 2] Socat Bridge Processes"
ps aux | grep socat || echo "[✗] No socat processes running"

# Check 3: Host Port Listening Status
echo ""
echo "[CHECK 3] Host (Termux) Listening Ports"
ss -tlnp 2>/dev/null | grep -E "(LISTEN|socat)" || netstat -tlnp 2>/dev/null | grep LISTEN || echo "   (Install ss: pkg install procps)"

# Check each port individually
echo ""
echo "[CHECK 3b] Individual Port Status:"
for port in 2222 3000 3001 3002 3003; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        echo "   [✓] Port $port is LISTENING on host"
    else
        echo "   [✗] Port $port is NOT listening on host"
    fi
done

# Check 4: PRoot Internal Status
echo ""
echo "[CHECK 4] Inside Debian PRoot:"
proot-distro login debian -- /bin/bash -c '
echo "--- Guest System ---"
if [ -f "/etc/resolv.conf" ]; then
    echo "DNS Configuration:"
    cat /etc/resolv.conf
else
    echo "[✗] /etc/resolv.conf not found!"
fi

echo ""
echo "--- Guest Listening Ports ---"
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "(No network tools installed)"

echo ""
echo "--- PM2 Services Status ---"
pm2 list 2>/dev/null || echo "PM2 not found or no services running"

echo ""
echo "--- SSHD Status ---"
if pgrep -x sshd > /dev/null; then
    echo "[✓] SSH daemon is running"
else
    echo "[✗] SSH daemon is NOT running"
fi
' 2>&1 || echo "   (Could not enter PRoot)"

# Check 5: Tailscale Status
echo ""
echo "[CHECK 5] Tailscale Connection"
if command -v tailscale >/dev/null 2>&1; then
    tailscale status --json 2>/dev/null | head -30 || echo "   (Tailscale not connected or error)"
else
    echo "[✗] Tailscale not installed. Run: pkg install tailscale"
fi

# Check 6: Firewall/Iptables Rules
echo ""
echo "[CHECK 6] Iptables Rules"
iptables -L -n 2>/dev/null | grep -E "(ACCEPT|DROP)" || echo "   (iptables not available or no rules)"

# Check 7: Network Interface Names
echo ""
echo "[CHECK 7] Network Interfaces"
ip link show 2>/dev/null | grep -E "(eth0|wlan|lo)" || ifconfig 2>/dev/null | head -10 || echo "   (Install iproute2: pkg install iproute2)"

# Check 8: Test Local Connectivity
echo ""
echo "[CHECK 8] Local Connectivity Tests"
for port in 3000 3001 3003; do
    if timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then
        echo "   [✓] localhost:$port is reachable"
    else
        echo "   [✗] localhost:$port is NOT reachable"
    fi
done

# Summary
echo ""
echo "=========================================="
echo "=== Diagnostic Summary ===="
echo "=========================================="

issues=0

if ! proot-distro list 2>/dev/null | grep -q debian; then
    echo "- [CRITICAL] Debian PRoot not installed"
    issues=$((issues + 1))
fi

if ! ps aux | grep socat >/dev/null 2>&1; then
    echo "- [CRITICAL] No socat bridges running"
    issues=$((issues + 1))
fi

if ! ss -tlnp 2>/dev/null | grep ":3000 " >/dev/null; then
    echo "- [ERROR] Port 3000 not listening"
    issues=$((issues + 1))
fi

if ! ss -tlnp 2>/dev/null | grep ":3001 " >/dev/null; then
    echo "- [ERROR] Port 3001 not listening"
    issues=$((issues + 1))
fi

if ! ss -tlnp 2>/dev/null | grep ":3003 " >/dev/null; then
    echo "- [ERROR] Port 3003 not listening"
    issues=$((issues + 1))
fi

echo ""
if [ $issues -eq 0 ]; then
    echo "[✓] All checks passed! Ports should be accessible."
    echo "   Try accessing: http://<PHONE>.tail5a917d.ts.net:3000"
else
    echo "[✗] Found $issue(s). Run quick-fix-termux.sh to resolve."
fi

echo ""
echo "=========================================="