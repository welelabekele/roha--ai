# Roha: Codespaces inference starter

This package prepares an Ollama text-understanding API and an optional CPU speech-transcription worker for Roha. It is not the complete Track 1 frontend, an already deployed service, or a tested production host.

## First run: text understanding

1. Create a private GitHub repository, for example `roha-ai`, and upload the **contents** of this folder, including `.devcontainer`. Never upload a real `.env`.
2. Choose **Code → Codespaces → Create codespace**. A 2-core/8-GB machine is a starting point for text inference. CPU latency must be measured; this is not a throughput guarantee.
3. The devcontainer installs Python dependencies and Ollama. If you uploaded after creating the codespace, run `bash scripts/setup.sh` manually.
4. Run `bash scripts/start.sh`. This starts loopback-only Ollama, downloads `qwen3:1.7b` (~1.4 GB), and serves the API on port 8000. Initial downloads can take time.
5. Open **Ports → 8000 → Open in Browser**. Keep both ports private for developer testing. Do not expose port 11434.
6. To show the generated token **only in your own terminal**, run:

   ```bash
   .venv/bin/python -c 'from dotenv import dotenv_values; print(dotenv_values(".env")["ROHA_API_TOKEN"])'
   ```

   Paste it into the private test page. Do not send it in chat, commit it, show it on a projected screen, or put it into the public Roha plugin. The test page holds it in memory only.
7. Click **Check model status**. `llm_downloaded: true` means weights exist; it does not prove a successful model answer. Ask a question and check `source: "ollama"`.
8. In a second terminal, run `.venv/bin/python scripts/smoke.py` for a real model/API check. It fails if the response used the fallback.

Use `ROHA_MODEL=qwen3:0.6b` in `.env` if 1.7B is too slow, then restart. Smaller weights can reduce language and instruction quality; retest. Try larger models only after measuring resources and preserving your demo time.

`bash scripts/start.sh` after stopping/restarting the codespace reuses downloaded weights. If another Ollama service already owns port 11434, it may use a different model directory; this script still connects to that service.

## Optional speech: Amharic, Afaan Oromo, Tigrinya, English

The selected family is **Meta Omnilingual ASR**, using `omniASR_CTC_300M_v2` (~1.3 GiB FP32 weights). Its published language list includes `amh_Ethi`, `orm_Latn`, `tir_Ethi`, and `eng_Latn`. The model/code license is Apache 2.0. Published memory/speed tables use GPUs; do not present those numbers as Codespaces CPU results.

This CTC model **does not accept language conditioning**. The requested language is tracked in Roha, but it does not force the recognizer to use that language. Recognition accuracy and language confusion require real recordings and native-speaker review. This package does not claim validated accuracy for any of the four languages.

1. Prefer a **4-core/16-GB Codespace**, if your account permits it. This spends the included core-hour allowance twice as fast as a 2-core machine. Speech dependencies and caches consume several GB; inspect `df -h` before and after installing.
2. Run `bash scripts/install-speech.sh`. It uses a separate environment so speech dependencies do not break the lightweight API. Python must be 3.10–3.12. The CPU PyTorch/fairseq2 ABI combination is pinned; installation must still be verified on your Codespace.
3. Upload a short recording using the Codespaces Explorer. Use test data and a consenting speaker.
4. Run `bash scripts/speech-smoke.sh /workspaces/YOUR_REPO/test.wav`. The first run downloads speech weights. Compare the actual output with the spoken words.
5. Only after that succeeds, set `ROHA_STT_ENABLED=1` in `.env`. Restart `scripts/start.sh`.
6. Open the test page. Record, stop, explicitly consent, and transcribe. Review the text before sending it to the LLM.

Input is limited to 8 MB and the first 30 seconds. Tell users this before recording. The speech worker exits after each request, releasing its model memory; this is slower than a persistent speech server. Ollama unloads weights after requests. One shared inference slot prevents simultaneous LLM and STT jobs in this API process.

The API uses a four-minute speech timeout to stop stalled jobs. This is a processing limit, not a form-session expiry; the Roha frontend must keep the learner's draft and recording until they decide what to do. The API deletes its temporary audio on ordinary completion/failure and has no conversation database. OS administrators and abrupt process termination are outside that guarantee.

If speech installation fails, leave it disabled and continue with typed text/your frontend's consented voice-note fallback. Do not silently replace it with a paid provider. Do not spend the remaining hackathon time debugging a large GPU stack.

## Language quality and spoken replies

`qwen3:1.7b` is a small general model, not a verified Ethiopian-language assistant. A language parameter is not evidence of good understanding. Test 10–20 natural utterances per language, including names, corrections, missing ID, and ambiguous requests. Record expected intent, returned intent, transcription mistakes, and native-speaker judgment. Begin with reviewed question wording and examples from your co-designers. Never invent a successful language evaluation.

No server TTS model is included. The test page uses a matching installed browser voice only. For Amharic/Oromo/Tigrinya questions, use recorded native-speaker audio when no suitable voice exists. Free-form spoken responses in all languages remain an integration task.

The built-in exact command shortcuts are English only and honestly report an English reply. Add reviewed command phrases in other languages to `deterministic()` after testing. Unrecognized phrases go to the model. Fallback text is English and explicitly marked as such.

## Architecture and integration

STT endpoint → reviewed transcript → `/v1/turn` → validated proposal → Roha's own dialogue/form engine → learner confirmation → permitted host action.

This service never clicks, submits, opens arbitrary URLs, scans host DOM, or reads a repository. It proposes actions. The frontend owns form state and saves drafts; this service has no persistent conversation state. Send up to four relevant previous turns when needed, not the full profile or all saved answers.

Endpoints:

| Endpoint | Purpose |
|---|---|
| `GET /health` | Process health, not model readiness |
| `GET /v1/status` | Model presence, speech configuration, task fields |
| `GET /v1/schema` | OpenAPI JSON |
| `POST /v1/turn` | Text understanding and proposed form action |
| `POST /v1/transcribe` | Optional consented speech transcription |

All `/v1` endpoints require `Authorization: Bearer <server token>`.

Example turn body:

```json
{
  "language": "am",
  "task": "registration",
  "field": "idRoute",
  "message": "መታወቂያ የለኝም። ምን ላድርግ?",
  "history": []
}
```

Language aliases: `am`/`amh`/`am-ET`, `om`/`orm`/`om-ET`, `ti`/`tir`/`ti-ET`, `en`/`eng`/`en-US`.

Question/field definitions in `TASKS` are server-owned demo definitions in English. Add your actual approved form schema and reviewed translations there. The three task types demonstrate reuse; this starter does not implement the full sign-up, jobs, or employer UI. The LLM receives only the active question and relevant supplied conversation. Values still need validation by the real form engine.

Possible actions: `clarify`, `explain`, `propose_answer`, `back`, `repeat`, `larger_text`, `save_draft`, `review`. There is no execute or submit action. A proposed answer always has `requires_confirmation: true`; every response has `executed: false`. Even valid JSON can contain a wrong or misleading answer: always show/read it back and allow correction.

For external Roha websites, call this service through **your host backend**. Keep the server token there and apply learner authentication, consent, per-user quotas, CSRF controls as applicable, and your approved field policy. A private Codespaces URL requires GitHub authorization and generally will not work as an anonymous external browser API. For a controlled external demo, port 8000 can be public behind this API's token, but keep the token server-side. Never make port 11434 public. CORS is not authentication.

Changing a port's visibility is done in the Codespaces Ports panel. The package does not change it automatically. The forwarded address normally looks like `https://CODESPACE-NAME-8000.app.github.dev`; copy the actual value from the Ports panel.

## Scope and security limits

This is a single-developer hackathon inference starter, not a production deployment. It has bearer authentication, explicit optional CORS origins, constrained fields/actions, response validation, global request throttling (30 turns/transcriptions per minute), bounded text/audio inputs, no model tools, no access logs, and limited inference concurrency. It has no user-account system, distributed quota store, durable queue, full upload gateway, production audit system, or complete denial-of-service defense. Use one Uvicorn worker. The server is trusted and receives any text/audio deliberately sent to it. Do not send private support needs, identity documents, credentials, or full profiles to this inference API.

Ordinary same-page JavaScript has host-page privileges; this backend does not change that. A host adapter or isolated iframe design must be implemented and audited separately in the actual plugin.

Codespaces is a temporary development host: default inactivity timeout is 30 minutes, configurable up to four hours; maximum running session lifetime is 12 hours before restart. No bypass/keep-alive hacks are included. Remote inference needs internet. Offline form controls/drafts and recorded question audio belong in the frontend and must keep working without this server.

GitHub Free personal accounts currently include 120 core-hours and 15 GB-month storage. That is approximately 60 hours on 2 cores or 30 hours on 4 cores if none has already been consumed. Storage is also metered while a stopped codespace exists. Check your own allowance and budget; set a zero overage budget/stop-at-limit where applicable. No payment method is required to use included personal usage; usage can stop at exhaustion. These terms can change.

## Verification

Run `.venv/bin/python -m unittest discover -s tests -v` for contract/security behavior tests. They mock Ollama: passing does not establish actual model accuracy, speech operation, CPU speed, or live Codespaces deployment. `scripts/smoke.py` and `scripts/speech-smoke.sh` are the required real-model checks after installation. API dependencies are bounded ranges; after a successful deployment, record an environment lock with `.venv/bin/python -m pip freeze > requirements.lock.txt`.

## Primary references checked 2026-11-14

- https://docs.github.com/en/billing/reference/product-usage-included
- https://docs.github.com/en/codespaces/troubleshooting/troubleshooting-included-usage
- https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace
- https://docs.github.com/en/codespaces/about-codespaces/understanding-the-codespace-lifecycle
- https://docs.ollama.com/linux
- https://docs.ollama.com/capabilities/structured-outputs
- https://ollama.com/library/qwen3:1.7b
- https://github.com/facebookresearch/omnilingual-asr
- https://github.com/facebookresearch/omnilingual-asr/blob/main/src/omnilingual_asr/models/wav2vec2_llama/lang_ids.py
- https://github.com/facebookresearch/omnilingual-asr/blob/main/src/omnilingual_asr/models/inference/README.md
- https://github.com/facebookresearch/fairseq2#installing-on-linux

Omnilingual ASR is selected over MMS here because MMS's published weights have CC-BY-NC 4.0 terms. Standard Whisper's tokenizer language list includes Amharic but does not list Afaan Oromo or Tigrinya. Do not claim that simply selecting a Whisper language code supports all three.
# roha--ai
