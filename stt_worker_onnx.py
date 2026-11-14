"""CPU-only ONNX alternative for Roha. Requires a 16-kHz mono PCM16 WAV."""
import contextlib
import json
import os
import sys
import time
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python stt_worker_onnx.py audio.wav')
    with wave.open(sys.argv[1], 'rb') as audio:
        if (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) != (1, 2, 16000):
            raise SystemExit('Use mono, 16-bit PCM WAV at 16000 Hz. The smoke script converts recordings.')
        if not 0 < audio.getnframes() / 16000 <= 30:
            raise SystemExit('Use a nonempty recording of 30 seconds or less.')
        raw = audio.readframes(audio.getnframes())
    directory = Path(os.getenv('ROHA_ONNX_MODEL_DIR', str(ROOT / '.runtime' / 'onnx-speech')))
    if not directory.is_absolute():
        directory = ROOT / directory
    for name in ['model.int8.onnx', 'tokens.txt']:
        if not (directory / name).is_file():
            raise SystemExit('ONNX model is missing. Run bash scripts/install-onnx-speech.sh first.')
    started = time.monotonic()
    with contextlib.redirect_stdout(sys.stderr):
        import numpy as np
        import sherpa_onnx
        samples = np.frombuffer(raw, dtype='<i2').astype(np.float32) / 32768.0
        recognizer = sherpa_onnx.OfflineRecognizer.from_omnilingual_asr_ctc(
            model=str(directory / 'model.int8.onnx'), tokens=str(directory / 'tokens.txt'),
            num_threads=max(1, min(4, int(os.getenv('ROHA_CPU_THREADS', '2')))), provider='cpu')
        stream = recognizer.create_stream()
        stream.accept_waveform(16000, samples)
        recognizer.decode_stream(stream)
        text = stream.result.text
    print(json.dumps({'text': text, 'source': 'onnx_omnilingual_ctc_300m_v2_int8',
                      'requires_review': True, 'language_detected': None,
                      'seconds_including_load': round(time.monotonic() - started, 3)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
