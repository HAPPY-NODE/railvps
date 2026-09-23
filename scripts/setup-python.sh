#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------
# Python environment check + bot-ready verification
# ---------------------------------------------------------------

echo "[python] verifying..."

python3 -V
pip3 -V

# quick import smoke test
python3 - <<'PY'
mods = [
    "requests", "aiohttp", "httpx", "flask", "fastapi",
    "telegram", "discord", "yaml", "psutil", "rich",
]
ok, fail = [], []
for m in mods:
    try:
        __import__(m)
        ok.append(m)
    except Exception:
        fail.append(m)
print(f"[python] OK: {', '.join(ok)}")
if fail:
    print(f"[python] missing (install later): {', '.join(fail)}")
PY

# venv helper for isolated bot projects
cat > /usr/local/bin/bot-venv <<'EOF'
#!/usr/bin/env bash
# usage: bot-venv <dir>
DIR="${1:-$HOME/botenv}"
python3 -m venv "$DIR"
"$DIR/bin/pip" -U pip setuptools wheel
echo "venv ready: source $DIR/bin/activate"
EOF
chmod +x /usr/local/bin/bot-venv

echo "[python] bot environment ready"
