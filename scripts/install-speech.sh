#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -c 'import sys; assert (3,10) <= sys.version_info[:2] <= (3,12), "Speech requires Python 3.10-3.12"'
printf 'Optional speech install: allow several GB of disk space. Prefer a 4-core/16-GB codespace.\n'
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends ffmpeg libsndfile1 build-essential cmake pkg-config
python3 -m venv .venv-stt
.venv-stt/bin/python -m pip install --upgrade pip
# Match the fairseq2/PyTorch C++ ABI. Do not mix CPU and CUDA builds.
.venv-stt/bin/python -m pip install torch==2.8.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cpu
.venv-stt/bin/python -m pip install 'fairseq2[arrow]==0.6.0' --extra-index-url https://fair.pkg.atmeta.com/fairseq2/whl/pt2.8.0/cpu
.venv-stt/bin/python -m pip install omnilingual-asr==0.2.0
.venv-stt/bin/python - <<'PY'
import torch
from omnilingual_asr.models.inference.pipeline import ASRInferencePipeline
from omnilingual_asr.models.wav2vec2_llama.lang_ids import supported_langs
assert torch.version.cuda is None, 'Expected the CPU PyTorch wheel'
for code in ['eng_Latn', 'amh_Ethi', 'orm_Latn', 'tir_Ethi']:
    assert code in supported_langs, f'Language missing: {code}'
print('Speech imports and language list verified. Model accuracy is not yet verified.')
PY
printf '\nNext: bash scripts/speech-smoke.sh /path/to/a-short-recording.wav\n'
printf 'After a successful transcription, set ROHA_STT_ENABLED=1 in .env and restart the API.\n'
