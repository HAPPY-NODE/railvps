FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Kolkata \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TERM=xterm-256color

# ---------------------------------------------------------------
# Layer 1: base system + build tools (cached aggressively)
# ---------------------------------------------------------------
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    bash bash-completion zsh ca-certificates curl wget git \
    sudo locales tzdata unzip zip tar xz-utils bzip2 p7zip-full \
    net-tools iproute2 iputils-ping traceroute dnsutils \
    nmap netcat-openbsd socat jq htop tree vim nano \
    openssh-server openssh-client sshpass \
    cron logrotate rsyslog \
    software-properties-common gnupg lsb-release \
    build-essential cmake pkg-config \
    procps file less which \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------
# Layer 2: Python full stack (for bots)
# ---------------------------------------------------------------
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev python3-setuptools \
    python3-wheel python3-distutils \
    libffi-dev libssl-dev libxml2-dev libxslt1-dev \
    libjpeg-dev zlib1g-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Global python packages useful for bots
RUN pip3 install --no-cache-dir -U pip setuptools wheel \
    && pip3 install --no-cache-dir \
    requests aiohttp httpx websockets \
    python-telegram-bot discord.py telebot \
    flask fastapi uvicorn gunicorn \
    pyyaml python-dotenv pymongo redis \
    beautifulsoup4 lxml pillow \
    psutil py-cpuinfo schedule \
    rich colorama

# ---------------------------------------------------------------
# Layer 3: systemd + dbus (best effort inside container)
# ---------------------------------------------------------------
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    systemd systemd-sysv dbus dbus-x11 \
    && rm -rf /var/lib/apt/lists/* \
    && (systemctl enable dbus 2>/dev/null || true)

# ---------------------------------------------------------------
# Layer 4: LXC / LXD (unprivileged only — no /dev/kvm on Railway)
# ---------------------------------------------------------------
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    lxc lxcfs lxc-templates uidmap \
    bridge-utils dnsmasq-base squashfuse \
    && rm -rf /var/lib/apt/lists/*

# snapd for LXD (Railway often blocks snapd start — fallback to classic lxc)
RUN apt-get update -y && apt-get install -y --no-install-recommends snapd \
    && rm -rf /var/lib/apt/lists/* || true

# ---------------------------------------------------------------
# Layer 5: proot — true mini-VPS without privileges
# ---------------------------------------------------------------
RUN apt-get update -y && apt-get install -y --no-install-recommends proot \
    && rm -rf /var/lib/apt/lists/* \
    || (curl -fsSL https://github.com/proot-me/proot/releases/download/v5.3.1/proot-v5.3.1-x86_64-static \
        -o /usr/local/bin/proot && chmod +x /usr/local/bin/proot)

# ---------------------------------------------------------------
# Layer 6: Docker CLI + dockerd (DinD best-effort, no privileged)
# ---------------------------------------------------------------
RUN curl -fsSL https://get.docker.com | sh \
    && (systemctl enable docker 2>/dev/null || true) \
    && mkdir -p /var/run/docker.sock /var/lib/docker /etc/docker

# Rootless docker fallback config
RUN mkdir -p /root/.config/docker && \
    echo '{"storage-driver":"vfs"}' > /root/.config/docker/daemon.json || true

# ---------------------------------------------------------------
# Layer 7: performance + memory tuning
# ---------------------------------------------------------------
# swappiness low, dirty ratios tuned for small RAM
RUN printf 'vm.swappiness=10\n\
vm.overcommit_memory=1\n\
vm.vfs_cache_pressure=50\n\
net.core.rmem_max=16777216\n\
net.core.wmem_max=16777216\n\
net.ipv4.tcp_fastopen=3\n\
fs.file-max=2097152\n' > /etc/sysctl.d/99-vps-tune.conf && \
    (sysctl --system 2>/dev/null || true)

# open files limits
RUN printf '* soft nofile 65535\n* hard nofile 65535\n* soft nproc 65535\n* hard nproc 65535\n' \
    > /etc/security/limits.d/99-vps.conf

# ---------------------------------------------------------------
# Layer 8: SSH hardening-ish but open (Railway needs password login)
# ---------------------------------------------------------------
RUN mkdir -p /var/run/sshd /root/.ssh && \
    echo "root:root123" | chpasswd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?UseDNS.*/UseDNS no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?X11Forwarding.*/X11Forwarding yes/' /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 60' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveCountMax 3' >> /etc/ssh/sshd_config && \
    usermod -aG docker,lxd,sudo root 2>/dev/null || true && \
    echo 'root ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/root

# ---------------------------------------------------------------
# Scripts into image
# ---------------------------------------------------------------
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/setup-swap.sh /usr/local/bin/setup-swap.sh
COPY scripts/setup-proot.sh /usr/local/bin/setup-proot.sh
COPY scripts/setup-lxc.sh /usr/local/bin/setup-lxc.sh
COPY scripts/setup-docker.sh /usr/local/bin/setup-docker.sh
COPY scripts/setup-python.sh /usr/local/bin/setup-python.sh
COPY motd /etc/motd

RUN chmod +x /usr/local/bin/*.sh

EXPOSE 22 8080

# zram-backed swap file size (MB) — overridable at runtime
ENV SWAP_MB=1024 \
    SSHX_ENABLE=1 \
    PROOT_ENABLE=1 \
    LXC_ENABLE=1 \
    DOCKER_ENABLE=1 \
    PYTHON_ENABLE=1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
