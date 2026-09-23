#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------
# Docker-in-Docker best-effort WITHOUT --privileged
# Railway won't give privileged, so dockerd may not start.
# We try; if blocked, docker CLI still works against a socket
# if Railway ever exposes one.
# ---------------------------------------------------------------

echo "[docker] configuring..."

# vfs storage driver works without overlay/kernel extras
mkdir -p /etc/docker /var/lib/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "storage-driver": "vfs",
  "iptables": false,
  "ip-forward": false,
  "bridge": "none",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON

# try starting dockerd in background
if pgrep -x dockerd >/dev/null 2>&1; then
  echo "[docker] dockerd already running"
else
  echo "[docker] attempting dockerd start (may fail without privileges)..."
  (dockerd >/var/log/dockerd.log 2>&1 &)
  sleep 3
  if pgrep -x dockerd >/dev/null 2>&1; then
    echo "[docker] dockerd UP"
  else
    echo "[docker] dockerd could not start (expected without --privileged)."
    echo "[docker] docker CLI installed; use proot/LXC for containers instead."
  fi
fi

# convenience
if command -v docker >/dev/null 2>&1; then
  docker version >/dev/null 2>&1 && echo "[docker] client+server OK" \
    || echo "[docker] client only (no server)"
fi

echo "[docker] done"
