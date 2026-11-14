Roha synthetic speech test pack

Eight short speech files in English, Amharic, Afaan Oromo, and Tigrinya; plus one deliberately silent negative control.
All WAV: 16,000 Hz, mono, signed PCM 16-bit. Speech clips were checked for nonzero signal and duration below 30 seconds.

IMPORTANT: These are computer-generated eSpeak NG 1.52.0 voices, not recordings of native speakers. They test your audio upload/decode/model pipeline. They are not an accuracy benchmark, native pronunciation reference, or proof of language support. The local-language phrases and generated pronunciation have not been reviewed by native speakers. Transcripts show the text sent to the synthesizer, not an independent human transcription of the generated sound.

HOW TO TEST
1. Extract and upload this roha-test-audio folder to /workspaces/roha--ai/ in Codespaces.
2. From /workspaces/roha--ai run:
   bash scripts/speech-smoke.sh roha-test-audio/en_repeat.wav
3. Then test am_no_id.wav, om_no_id.wav, and ti_name.wav in the same way.
4. Compare the output with transcripts.csv. Ignore punctuation/case differences for this initial test.
5. silence_control.wav should not produce a plausible personal answer; use it to detect hallucination on silence.
6. A failed transcription of these robotic samples alone does not prove the model cannot recognize natural speech. Before the hackathon demo, repeat testing with consenting native speakers on real phones.

These clips test STT only. LLM interpretation and actual form actions must be tested separately. They contain no real personal data; Sara is a fictional test name.

GENERATION
eSpeak NG 1.52.0, 145 words/minute; original output converted to PCM WAV with FFmpeg. No model credentials or API tokens required to use these files. No synthesizer binary, voice database, or source code is included in this pack.
Project language list: https://github.com/espeak-ng/espeak-ng/blob/master/docs/languages.md
Project licensing: https://github.com/espeak-ng/espeak-ng/blob/master/COPYING
Debian package source: https://deb.debian.org/debian/pool/main/e/espeak-ng/
