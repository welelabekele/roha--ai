#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .runtime
# Load only known settings; never source arbitrary .env text as shell commands.
export OLLAMA_HOST=127.0.0.1:11434
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_MAX_QUEUE=2
export OLLAMA_KEEP_ALIVE=0
export OLLAMA_NO_CLOUD=1
export OLLAMA_MODELS="$PWD/.runtime/models"
if ! curl --silent --fail http://127.0.0.1:11434/api/tags >/dev/null; then
  nohup ollama serve >.runtime/ollama.log 2>&1 &
fi
for attempt in {1..30}; do
  if curl --silent --fail http://127.0.0.1:11434/api/tags >/dev/null; then break; fi
  sleep 1
done
curl --silent --fail http://127.0.0.1:11434/api/tags >/dev/null || {
  printf 'Ollama did not start. Inspect .runtime/ollama.log\n'; exit 1;
}
model="$(.venv/bin/python -c 'from dotenv import dotenv_values; print(dotenv_values(".env").get("ROHA_MODEL") or "qwen3:1.7b")')"
ollama pull "$model"
printf '\nOpen port 8000 in Codespaces. Keep port 11434 private.\n'
exec .venv/bin/python -m uvicorn app:app --host 0.0.0.0 --port 8000 --workers 1 --no-access-log
