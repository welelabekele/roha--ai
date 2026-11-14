#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# != 1 ]]; then printf 'Usage: bash scripts/speech-smoke-onnx.sh recording.wav\n'; exit 2; fi
speech_tmp="$(mktemp -d)"
trap 'rm -rf "$speech_tmp"' EXIT
ffmpeg -nostdin -v error -protocol_whitelist file,pipe -i "$1" -t 30 -ac 1 -ar 16000 "$speech_tmp/audio.wav"
.venv-onnx/bin/python stt_worker_onnx.py "$speech_tmp/audio.wav"
