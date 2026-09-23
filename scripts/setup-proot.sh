#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------
# proot mini-VPS: full Ubuntu userland chroot-like env, zero privs
# ---------------------------------------------------------------

ROOTFS="/opt/proot-ubuntu"
ROOTFS_TARBALL_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.5-base-amd64.tar.gz"

if [ -x "$ROOTFS/bin/bash" ]; then
  echo "[proot] rootfs already present at $ROOTFS"
else
  echo "[proot] downloading ubuntu-base rootfs..."
  mkdir -p "$ROOTFS"
  TMP=$(mktemp)
  if curl -fsSL "$ROOTFS_TARBALL_URL" -o "$TMP"; then
    tar -xzf "$TMP" -C "$ROOTFS" 2>/dev/null || tar -xf "$TMP" -C "$ROOTFS"
    rm -f "$TMP"
    echo "[proot] rootfs ready"
  else
    echo "[proot] rootfs download failed — using host as rootfs fallback"
    ROOTFS="/"
    rm -f "$TMP"
  fi
fi

# launcher: enter mini-VPS
cat > /usr/local/bin/vps-proot <<EOF
#!/usr/bin/env bash
ROOTFS="$ROOTFS"
exec proot \\
  -r "\$ROOTFS" \\
  -b /dev \\
  -b /proc \\
  -b /sys \\
  -b /etc/resolv.conf \\
  -w /root \\
  -0 \\
  /bin/bash -l "\$@"
EOF
chmod +x /usr/local/bin/vps-proot

# one-shot setup inside proot (apt, python, ssh)
cat > /usr/local/bin/vps-proot-setup <<'EOF'
#!/usr/bin/env bash
vps-proot -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y && apt-get install -y \
    openssh-server sudo curl wget git htop nano python3 python3-pip \
    net-tools iproute2 && \
  echo "root:root123" | chpasswd && \
  echo "[proot] setup complete — run: vps-proot"
'
EOF
chmod +x /usr/local/bin/vps-proot-setup

echo "[proot] commands installed:"
echo "  vps-proot         -> enter mini-VPS shell"
echo "  vps-proot-setup   -> one-time packages inside proot"
