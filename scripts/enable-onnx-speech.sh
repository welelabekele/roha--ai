#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
.venv/bin/python - <<'PY'
from pathlib import Path
from datetime import datetime, timezone
from dotenv import set_key
import os
import shutil

for p in [Path('.venv-onnx/bin/python'), Path('.runtime/onnx-speech/model.int8.onnx'),
          Path('.runtime/onnx-speech/tokens.txt'), Path('stt_worker_onnx.py')]:
    if not p.exists():
        raise SystemExit('Install and test ONNX speech before enabling it: missing ' + str(p))
if not Path('.env').exists():
    raise SystemExit('Expected the existing Roha .env. Run the original setup first.')
ignore = Path('.gitignore')
content = ignore.read_text() if ignore.exists() else ''
for entry in ['.env', '.runtime/', '.venv-onnx/']:
    if entry not in content.splitlines():
        content += '\n' + entry + '\n'
ignore.write_text(content)
backup = Path('.runtime') / ('before-onnx-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
backup.mkdir(parents=True, exist_ok=True)
os.chmod(backup, 0o700)
for name in ['stt_worker.py', 'scripts/speech-smoke.sh', '.env']:
    source = Path(name)
    if source.exists():
        target = backup / source.name
        shutil.copy2(source, target)
        os.chmod(target, 0o600)
shutil.copy2('stt_worker_onnx.py', 'stt_worker.py')
# Preserve the original command name as well as providing a separate test command.
Path('scripts/speech-smoke.sh').write_text('''#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# != 1 ]]; then printf 'Pass one audio filename.\\n'; exit 2; fi
speech_tmp="$(mktemp -d)"
trap 'rm -rf "$speech_tmp"' EXIT
ffmpeg -nostdin -v error -protocol_whitelist file,pipe -i "$1" -t 30 -ac 1 -ar 16000 "$speech_tmp/audio.wav"
.venv-onnx/bin/python stt_worker.py "$speech_tmp/audio.wav"
''')
set_key('.env', 'ROHA_STT_PYTHON', '.venv-onnx/bin/python')
set_key('.env', 'ROHA_STT_MODEL', 'onnx_omnilingual_ctc_300m_v2_int8')
set_key('.env', 'ROHA_STT_ENABLED', '1')
os.chmod('.env', 0o600)
print('ONNX speech enabled. Restart Roha with bash scripts/start.sh.')
print('Previous files were backed up under .runtime. Your API token was preserved.')
PY
