# Roha ONNX speech alternative

This replaces the PyTorch/Fairseq speech loader with an INT8 ONNX export of **Omnilingual ASR CTC 300M V2**, executed using sherpa-onnx on CPU. It does not change app.py, Qwen, or language generation. It is an alternative to the loader receiving SIGTERM, not a proven diagnosis of that termination.

## Install and test

Upload Roha_ONNX_Speech_Fix.zip to the existing `/workspaces/roha--ai` repository. In that directory:

```bash
.venv/bin/python -m zipfile -e Roha_ONNX_Speech_Fix.zip .
bash scripts/install-onnx-speech.sh
bash scripts/speech-smoke-onnx.sh .runtime/onnx-speech/reference-en.wav
```

The installer creates a separate `.venv-onnx` and downloads a 292,313,120-byte archive once. Extracted model weights are 365,841,453 bytes. It checks SHA-256 of the archive, model, and tokenizer. It keeps the existing PyTorch environment and does not enable or modify the API during installation. No API key or paid inference provider is used. The model is not included in this small ZIP.

Now test consenting speakers' actual recordings, especially names and each required language. The previous eSpeak clips are robotic; this model misrecognized several during testing. Do not interpret file execution as proof of correct transcription. CTC does not accept a language-conditioning argument; a requested language cannot force it into the right script.

## Enable after successful tests

Stop the API terminal with Ctrl+C, then run:

```bash
bash scripts/enable-onnx-speech.sh
bash scripts/start.sh
```

The enable script backs up the old worker, smoke script, and .env under the ignored `.runtime` folder, sets private backup permissions, replaces `stt_worker.py`, updates the existing smoke command, and points `ROHA_STT_PYTHON` to `.venv-onnx/bin/python`. It preserves the API token. It updates .gitignore for local runtime files. Do not commit .env or backups. Previously tracked files remain tracked even after an ignore rule is added; inspect `git status` before committing.

After enabling, the existing `/v1/transcribe` endpoint and recording test page use the new worker. The original smoke command also uses it. In the server process, audio consent and upload checks still apply. Runtime inference uses no network once the models are installed. Serving it through Codespaces still requires a connection from the learner's device.

## Measured execution in the preparation environment

Actual CPU inference was run with sherpa-onnx 2.0.1, NumPy 2.2.6, Python 3.12, two runtime threads, and the exact checksummed V2 model:

- Model initialization: approximately 2.1 seconds in the benchmark.
- Six synthetic/silence fixtures completed without termination.
- Short fixture decode times: approximately 0.6–1.9 seconds, excluding model initialization.
- Peak measured process RSS in that benchmark: approximately 561 MiB.
- Silence produced empty text.
- A natural English reference clip from the publisher's sample files decoded as: "ask not what your country can do for you ask what you can do for your country". Decode time was approximately 1.6 seconds; this is one fixture, not an accuracy benchmark.
- The real Roha `/v1/transcribe` endpoint returned HTTP 200 with that natural reference through the ONNX subprocess, with `requires_review: true` and `retained: false`. A request without consent was rejected with HTTP 400.
- The synthetic Amharic and Oromo clips were rendered as incorrect Latin text; the synthetic Tigrinya sample was rendered in Thai script. This test does not establish those languages' recognition accuracy. English synthetic clips also had errors.

These figures describe a local preparation environment, not your Codespace or a service-level guarantee. Actual Roha worker calls start a fresh recognizer for each clip. Accuracy, native-speaker performance, and host CPU latency require testing on your device. This change does not fix Qwen's local-language replies.

## Git recovery

The commit shown in your log, `5b26a35`, can usually be preserved after your hard reset by running:

```bash
git branch rescue-local-5b26a35 5b26a35
```

This creates a reference without replacing current files. If the branch already exists, leave it. Before a future pull, commit only intended source files or stash them; inspect merge conflicts instead of using reset --hard to discard local work. Never force-push merely to bypass a non-fast-forward error.

## Model and runtime sources

- Model artifact: https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-v2-int8-2026-02-05.tar.bz2
- Official export workflow: https://github.com/k2-fsa/sherpa-onnx/blob/master/.github/workflows/export-omnilingual-asr-to-onnx.yaml
- Python API example: https://github.com/k2-fsa/sherpa-onnx/blob/master/python-api-examples/offline-omnilingual-asr-ctc-decode-files.py
- Runtime documentation: https://k2-fsa.github.io/sherpa/onnx/omnilingual-asr/python.html

The model archive includes Meta's Apache 2.0 license notice; the installer retains it beside the model. Preserve upstream notices when distributing model weights. Runtime packages install their own license metadata.
