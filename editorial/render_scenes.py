"""Render the bilingual meeting transcripts with local Kokoro weights and FFmpeg."""

import argparse
import json
import re
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
import onnxruntime as ort
import soundfile as sf
from kokoro_onnx import Kokoro


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "editorial" / "audio"
SAMPLE_RATE = 24000

# First voice reads the scene or player, second voice plays the stakeholder.
DEFAULT_CAST = {"es": ("em_alex", "ef_dora"), "en": ("am_michael", "af_heart")}
CAST = {
    "news-2026-11-netflix-comedy": {"en": ("am_michael", "af_bella")},
    "news-2026-11-walmart-delivery": {"en": ("am_michael", "af_sarah")},
    "gira": {"en": ("am_puck", "af_bella")},
    "muelle": {"es": ("ef_dora", "em_alex"), "en": ("af_heart", "am_michael")},
    "taller": {"es": ("ef_dora", "em_alex"), "en": ("af_sarah", "am_fenrir")},
}
# Spoken spellings help the Spanish phonemizer with foreign names. Captions
# retain their published spelling.
SPANISH_NAMES = {
    "Nikki Glaser": "Niki Gléiser",
    "Netflix": "Nétflix",
    "Walmart": "Uólmart",
    "Spotify": "Espótifai",
    "Disney": "Dísni",
}


def render(model, case_id, lang, scene):
    filename = scene["file"]
    if not re.fullmatch(r"[a-z0-9-]+", case_id) or not re.fullmatch(
        rf"{re.escape(case_id)}-v[1-9][0-9]*-{lang}\.mp3", filename
    ):
        raise ValueError(f"Unexpected audio filename: {filename}")
    voices = CAST.get(case_id, {}).get(lang, DEFAULT_CAST[lang])
    lines = scene["lines"]
    roles = list(dict.fromkeys(line["speaker"] for line in lines))
    if len(roles) != len(voices):
        raise ValueError(f"{filename} requires two speakers")
    parts = [np.zeros(int(SAMPLE_RATE * 0.09), dtype=np.float32)]
    for i, line in enumerate(lines):
        text = line["text"]
        if lang == "es":
            for name, pronunciation in SPANISH_NAMES.items():
                text = text.replace(name, pronunciation)
        role = roles.index(line["speaker"])
        samples, rate = model.create(
            text, voice=voices[role], lang="es" if lang == "es" else "en-us",
            speed=(1.00, 0.98)[role], sentence_pause=0.30, clause_pause=0.10,
        )
        if rate != SAMPLE_RATE or not len(samples) or not np.isfinite(samples).all():
            raise ValueError(f"Missing speech for {filename}, line {i + 1}")
        # Preserve line endings and breaths while making the speaker change brisk.
        voiced = np.flatnonzero(np.abs(samples) > 0.003)
        if not len(voiced):
            raise ValueError(f"Silent audio for {filename}, line {i + 1}")
        edge = int(rate * 0.055)
        parts.append(samples[max(0, voiced[0] - edge):voiced[-1] + edge + 1])
        gap = 0.32 if i < len(lines) - 1 else 0.16
        parts.append(np.zeros(int(rate * gap), dtype=np.float32))

    with TemporaryDirectory(dir=OUTPUT) as tmp:
        wav = Path(tmp) / "scene.wav"
        target = Path(tmp) / filename
        sf.write(wav, np.concatenate(parts), SAMPLE_RATE, subtype="PCM_24")
        subprocess.run([
            "ffmpeg", "-v", "error", "-nostdin", "-i", str(wav),
            "-af", "loudnorm=I=-16:TP=-2:LRA=7", "-ar", str(SAMPLE_RATE),
            "-ac", "1", "-codec:a", "libmp3lame", "-b:a", "96k", str(target),
        ], check=True)
        target.replace(OUTPUT / filename)
    print(f"{filename} ({sum(map(len, parts)) / SAMPLE_RATE:.1f} s)", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", required=True, type=Path)
    parser.add_argument("--lang", choices=["es", "en"])
    parser.add_argument("ids", nargs="*", help="Case IDs; defaults to every scripted case")
    args = parser.parse_args()
    feed = json.loads((ROOT / "editorial/feed.json").read_text())["cases"]
    cases = {c["id"]: c for c in feed}
    for path in sorted((ROOT / "cases").rglob("*.json")):
        cases[path.stem] = json.loads(path.read_text())
    ids = args.ids or [key for key, value in cases.items() if "scene" in value]
    for key in ids:
        if key not in cases:
            parser.error(f"Unknown case ID: {key}")
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    ort.disable_telemetry_events()
    session = ort.InferenceSession(
        str(args.models / "kokoro-v1.0.onnx"), options, providers=["CPUExecutionProvider"]
    )
    model = Kokoro.from_session(session, str(args.models / "voices-v1.0.bin"))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for key in ids:
        for lang in ([args.lang] if args.lang else ["es", "en"]):
            content = cases[key] if lang == "es" else cases[key]["en"]
            render(model, key, lang, content["scene"])


if __name__ == "__main__":
    main()
