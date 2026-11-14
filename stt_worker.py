"""Optional CPU speech worker; model loading is intentionally outside the API process."""
import contextlib
import json
import os
import sys


def main():
    with contextlib.redirect_stdout(sys.stderr):
        import torch
        from omnilingual_asr.models.inference.pipeline import ASRInferencePipeline
        torch.set_num_threads(int(os.getenv('ROHA_CPU_THREADS', '2')))
        pipeline = ASRInferencePipeline(
            model_card=os.getenv('ROHA_STT_MODEL', 'omniASR_CTC_300M_v2'),
            device='cpu', dtype=torch.float32)
        # CTC does NOT support language conditioning; do not pass language codes.
        text = pipeline.transcribe([sys.argv[1]], batch_size=1)[0]
    print(json.dumps({'text': text}, ensure_ascii=False))


if __name__ == '__main__':
    main()
