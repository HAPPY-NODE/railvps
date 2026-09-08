# Ubuntu VPS (Railway Deploy)

Ubuntu-based VPS container ready to deploy on Railway. Includes SSH, Docker, systemd, and LXC.

## What's Included

- **SSH** — root access (`root` / `root123`)
- **Docker** — via get.docker.com
- **systemd** — installed for service management
- **LXC/LXD** — containers
- **sshx** — prints a shareable terminal link in logs

## Deploy on Railway

1. Push this repo to GitHub
2. Import it in Railway
3. Deployment logs will show the **sshx link** and SSH credentials

## Access

```
SSH:     root@<host>
Password: root123
```

## Notes

- Railway does **not** provide KVM/nested virtualization (`/dev/kvm`). LXC runs unprivileged only.
- `systemd` is installed but Docker containers typically run with a custom init; use `service` or run commands directly.
- Change the root password after first login.

## License

MIT License (c) 2026 HAPPY_NODE