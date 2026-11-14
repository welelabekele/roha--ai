#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# != 1 ]]; then printf 'Usage: bash scripts/speech-smoke.sh /path/to/short-audio.wav\n'; exit 2; fi
source_audio="$1"
speech_tmp="$(mktemp -d)"
trap 'rm -rf "$speech_tmp"' EXIT
ffmpeg -nostdin -v error -protocol_whitelist file,pipe -i "$source_audio" -t 30 -ac 1 -ar 16000 "$speech_tmp/audio.wav"
.venv-stt/bin/python stt_worker.py "$speech_tmp/audio.wav"
