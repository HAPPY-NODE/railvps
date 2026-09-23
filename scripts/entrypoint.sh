#!/usr/bin/env bash
set -uo pipefail

log() { echo "[entrypoint] $*"; }

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------
# 1. Memory: create swap early (biggest free-tier win)
# ---------------------------------------------------------------
if [ "${SWAP_MB:-1024}" != "0" ]; then
  /usr/local/bin/setup-swap.sh || log "swap setup skipped"
fi

# ---------------------------------------------------------------
# 2. Apply sysctls if possible
# ---------------------------------------------------------------
sysctl --system >/dev/null 2>&1 || true

# ---------------------------------------------------------------
# 3. Hostname + motd
# ---------------------------------------------------------------
hostname railvps 2>/dev/null || true

# ---------------------------------------------------------------
# 4. Start base services
# ---------------------------------------------------------------
log "starting rsyslog/cron..."
service rsyslog start 2>/dev/null || true
service cron start 2>/dev/null || true
service dbus start 2>/dev/null || true

# ---------------------------------------------------------------
# 5. SSH
# ---------------------------------------------------------------
log "starting SSH on :22 ..."
mkdir -p /var/run/sshd
/usr/sbin/sshd

# ---------------------------------------------------------------
# 6. Optional modules
# ---------------------------------------------------------------
[ "${PYTHON_ENABLE:-1}" = "1" ] && /usr/local/bin/setup-python.sh || true
[ "${PROOT_ENABLE:-1}"  = "1" ] && /usr/local/bin/setup-proot.sh  || true
[ "${LXC_ENABLE:-1}"    = "1" ] && /usr/local/bin/setup-lxc.sh    || true
[ "${DOCKER_ENABLE:-1}" = "1" ] && /usr/local/bin/setup-docker.sh || true

# ---------------------------------------------------------------
# 7. Banner
# ---------------------------------------------------------------
cat <<'BANNER'
========================================
 RAILVPS READY
 SSH : root / root123
 Python : python3 + bot libs ready
 Proot  : vps-proot
 LXC    : lxc-ls (unprivileged)
 Docker : docker ps (best-effort)
 Swap   : free -h
========================================
BANNER

# ---------------------------------------------------------------
# 8. sshx share link (browser terminal)
# ---------------------------------------------------------------
if [ "${SSHX_ENABLE:-1}" = "1" ]; then
  log "generating sshx link..."
  ( curl -fsSL https://sshx.io/get | sh -s run ) &
fi

# ---------------------------------------------------------------
# 9. Keep container alive + lightweight health logger
# ---------------------------------------------------------------
while true; do
  TS=$(date '+%Y-%m-%d %H:%M:%S')
  MEM=$(free -m | awk '/Mem:/{printf "%d/%dMB", $3,$2}')
  LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
  DISK=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')
  echo "[health] $TS mem=$MEM load=$LOAD disk=$DISK"
  sleep 60
done
