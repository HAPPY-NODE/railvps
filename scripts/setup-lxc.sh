#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------
# LXC unprivileged — Railway has no /dev/kvm, so no full VMs.
# This still gives you real container isolation where allowed.
# ---------------------------------------------------------------

echo "[lxc] checking capabilities..."

# subuid/subgid for rootless
if ! grep -q '^root:' /etc/subuid 2>/dev/null; then
  echo "root:100000:65536" >> /etc/subuid
  echo "root:100000:65536" >> /etc/subgid
fi

mkdir -p /var/lib/lxc /var/lib/lxcsnaps /etc/lxc
chmod 755 /var/lib/lxc

# default unprivileged config
cat > /etc/lxc/lxc.conf <<'CFG' || true
lxc.lxcpath = /var/lib/lxc
CFG

# storage backend
mkdir -p /var/lib/lxc/common

# try creating a test container — will fail gracefully without privileges
if command -v lxc-create >/dev/null 2>&1; then
  echo "[lxc] attempting unprivileged test container..."
  if lxc-create -t download -n railtest -- \
      -d ubuntu -r jammy -a amd64 >/tmp/lxc-create.log 2>&1; then
    echo "[lxc] railtest created — starting..."
    lxc-start -n railtest -d 2>/dev/null || true
    echo "[lxc] OK — manage with: lxc-ls, lxc-attach -n railtest"
  else
    echo "[lxc] unprivileged create blocked on this host (expected on Railway)."
    echo "[lxc] use proot instead: vps-proot"
    tail -5 /tmp/lxc-create.log 2>/dev/null || true
  fi
fi

# LXD via snap (best effort — snapd often can't start in container)
if command -v snap >/dev/null 2>&1; then
  echo "[lxc] trying lxd via snap..."
  (snap install lxd >/tmp/lxd-snap.log 2>&1 && \
   snap start lxd >/dev/null 2>&1 && \
   lxd init --auto >/dev/null 2>&1 && \
   echo "[lxd] ready") || echo "[lxd] unavailable here — use proot"
fi

echo "[lxc] done"
