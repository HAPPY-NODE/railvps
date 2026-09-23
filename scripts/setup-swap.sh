#!/usr/bin/env bash
set -euo pipefail

SWAP_MB="${SWAP_MB:-1024}"
SWAPFILE="/swapfile-railvps"

if swapon --show=NAME --noheadings 2>/dev/null | grep -q "$SWAPFILE"; then
  echo "[swap] already active"
  exit 0
fi

echo "[swap] creating ${SWAP_MB}MB swapfile..."

# fallocate is fastest; dd fallback
if ! fallocate -l "${SWAP_MB}M" "$SWAPFILE" 2>/dev/null; then
  dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SWAP_MB" status=none
fi

chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE" >/dev/null
swapon "$SWAPFILE" || {
  echo "[swap] swapon failed (container may lack privilege) — continuing without swap"
  rm -f "$SWAPFILE"
  exit 0
}

# persist in fstab for restarts inside same container life
grep -q "$SWAPFILE" /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab

echo "[swap] active:"
swapon --show
free -h
