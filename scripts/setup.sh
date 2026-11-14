#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv
.venv/bin/python -m pip install --quiet --upgrade pip
.venv/bin/python -m pip install --quiet -r requirements.txt
if [[ ! -f .env ]]; then
  cp .env.example .env
fi
.venv/bin/python - <<'PY'
from pathlib import Path
from dotenv import dotenv_values, set_key
import secrets, os
p = Path('.env')
if len(dotenv_values(p).get('ROHA_API_TOKEN') or '') < 32:
    set_key(p, 'ROHA_API_TOKEN', secrets.token_urlsafe(32))
os.chmod(p, 0o600)
PY
if ! command -v ollama >/dev/null 2>&1; then
  curl --fail --show-error --location https://ollama.com/install.sh -o /tmp/roha-install-ollama.sh
  sh /tmp/roha-install-ollama.sh
fi
printf '\nSetup complete. Run: bash scripts/start.sh\n'
