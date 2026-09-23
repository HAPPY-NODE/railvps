# RailVPS — Optimized Ubuntu Mini-VPS on Railway

Max-performance Ubuntu container for Railway free tier: SSH, proot mini-VPS,
unprivileged LXC, best-effort Docker, full Python bot stack, swap + memory tuning.

## What's Included

| Feature | Status on Railway |
|---------|-------------------|
| SSH root access (`root` / `root123`) | Works |
| sshx browser terminal link in logs | Works |
| Python 3 + bot libs (telegram, discord, flask, fastapi…) | Works |
| `bot-venv` isolated bot environments | Works |
| Swap (default 1024MB, `SWAP_MB` env) | Works (best effort) |
| sysctl + nofile tuning | Applied |
| proot mini-VPS (`vps-proot`) | Works — no privileges needed |
| LXC unprivileged | May be blocked — falls back gracefully |
| LXD via snap | Best effort — often blocked |
| Docker-in-Docker | Best effort — needs `--privileged` (Railway won't give it) |
| KVM / nested virt | **Not available** — Railway has no `/dev/kvm` |
| systemd | Partial (container init limits) |

## Deploy on Railway

1. Push this repo to GitHub
2. Import in Railway (it detects `Dockerfile` + `railway.json`)
3. Open **Deploy Logs** → copy the **sshx link** and SSH creds

## Environment Variables

| Var | Default | Purpose |
|-----|---------|---------|
| `SWAP_MB` | `1024` | Swap file size in MB (`0` disables) |
| `SSHX_ENABLE` | `1` | Print sshx share link |
| `PROOT_ENABLE` | `1` | Install `vps-proot` launcher |
| `LXC_ENABLE` | `1` | Attempt unprivileged LXC |
| `DOCKER_ENABLE` | `1` | Attempt dockerd start |
| `PYTHON_ENABLE` | `1` | Verify python bot stack |

## Access

```
SSH:      root@<host>
Password: root123
Browser:  sshx link from deploy logs
```

## Commands Inside the VPS

```bash
free -h                 # memory + swap
htop                    # processes
vps-proot               # enter proot mini-VPS
vps-proot-setup         # packages inside proot (one time)
bot-venv ~/mybot        # isolated python env for a bot
python3 bot.py          # run your bot
lxc-ls                  # list LXC containers (if available)
docker ps               # docker (if dockerd started)
```

## Run a Python Bot

```bash
bot-venv ~/telegram-bot
source ~/telegram-bot/bin/activate
pip install python-telegram-bot
# upload bot.py, then:
nohup python bot.py > bot.log 2>&1 &
```

## Performance Tuning Applied

- `vm.swappiness=10`, `overcommit_memory=1`, `vfs_cache_pressure=50`
- TCP fastopen, larger rmem/wmem
- `nofile`/`nproc` raised to 65535
- pip cache disabled, lean apt layering for faster builds
- Health line (mem/load/disk) every 60s in Railway logs

## Honest Limits

- **No KVM** — Railway is containers-only. Real KVM needs a real VPS (Hetzner, OVH, etc.).
- **Docker-in-Docker** usually fails without `--privileged`; proot/LXC are the path here.
- **Resource ceilings** are Railway's free-tier numbers — no Dockerfile can raise them.
- Change the root password after first login.

## License

MIT License (c) 2026 HAPPY_NODE
