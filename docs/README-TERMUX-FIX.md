# 🔧 OpenClaw VPS - Port Connection Fix Guide

## Problem
You're getting **timeout errors** when accessing ports through Tailscale:
- `http://phone.tail5a917d.ts.net:3000` (Mission Control)
- `http://phone.tail5a917d.ts.net:3001` (OpenClaw)  
- `http://phone.tail5a917d.ts.net:3011` (Perplexica)
- `ssh -p 2222 root@phone.tail5a917d.ts.net`

## Root Cause
The socat port bridges aren't forwarding traffic correctly between Termux host and