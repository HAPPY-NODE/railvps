FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install -y \
    openssh-server sudo curl wget git ca-certificates \
    net-tools iproute2 tzdata htop neofetch \
    systemd systemd-sysv dbus dbus-x11 \
    lxc lxd lxcfs uidmap bridge-utils dnsmasq-base \
    gnupg lsb-release software-properties-common

RUN curl -fsSL https://get.docker.com | sh && \
    systemctl enable docker 2>/dev/null || true

RUN mkdir -p /var/run/sshd && \
    echo "root:root123" | chpasswd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    usermod -aG docker,lxd root 2>/dev/null || true

EXPOSE 22

CMD bash -c "\
    service ssh start && \
    echo '========================================' && \
    echo ' UBUNTU VPS READY' && \
    echo ' SSH: root / root123' && \
    echo '========================================' && \
    echo ' SSHX LINK BELOW:' && \
    curl -sSf https://sshx.io/get | sh -s run"