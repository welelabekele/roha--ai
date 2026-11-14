#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv-onnx
.venv-onnx/bin/python -m pip install --only-binary=:all: sherpa-onnx==2.0.1 numpy==2.2.6
mkdir -p .runtime/onnx-speech
.venv-onnx/bin/python - <<'PY'
from pathlib import Path
import hashlib
import shutil
import tarfile
import urllib.request

root = Path('.runtime/onnx-speech')
expected = {
    'model.int8.onnx': 'e3042b2f3b3ef0af2211bf99d2b4bf94a21f5ac0e9898827e7dd6d003a860e91',
    'tokens.txt': '7d99997ef207ff14c2cfe825f2aa037528ea250113cc3c6392bfe49326884ba6',
}
def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()
if not all((root / n).exists() and digest(root / n) == h for n, h in expected.items()):
    archive = root / 'model-download.tar.bz2'
    url = ('https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
           'sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-v2-int8-2026-02-05.tar.bz2')
    print('Downloading 292 MB ONNX model archive. This is a one-time download.', flush=True)
    with urllib.request.urlopen(url, timeout=60) as response, archive.open('wb') as target:
        shutil.copyfileobj(response, target)
    if digest(archive) != '951b32409aade32bd525310bb39e9666773ba3fc611a39e817f620936d76c631':
        raise SystemExit('Archive checksum mismatch. Do not use these weights; retry the download.')
    with tarfile.open(archive, 'r:bz2') as bundle:
        for member in bundle:
            name = Path(member.name).name
            if member.isfile() and name in ['model.int8.onnx', 'tokens.txt', 'LICENSE', 'README.md', 'en.wav']:
                name = 'reference-en.wav' if name == 'en.wav' else name
                with bundle.extractfile(member) as source, (root / (name + '.partial')).open('wb') as dest:
                    shutil.copyfileobj(source, dest)
                (root / (name + '.partial')).replace(root / name)
    for name, checksum in expected.items():
        if digest(root / name) != checksum:
            raise SystemExit('Extracted model checksum mismatch: ' + name)
    archive.unlink()
    print('Model downloaded and checksums verified.', flush=True)
else:
    print('Existing ONNX model verified; no download needed.', flush=True)
PY
printf '\nInstalled. Test: bash scripts/speech-smoke-onnx.sh .runtime/onnx-speech/reference-en.wav\n'
printf 'The API has not been changed. Enable it only after testing.\n'
