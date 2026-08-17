"""Audio preparation: decode, vocal-focused enhancement, optional stem split.

Everything funnels through ffmpeg so any input container/codec works. Each
prepared variant is a 16 kHz mono WAV, which is what Whisper-family models
expect.

Variants, cheapest first:

- "original": plain decode. Baseline pass; sometimes the model does better
  with full-band context than with any filtering.
- "enhanced": a vocal-intelligibility filter chain. Pop vocals sit in the
  stereo center and in the 150 Hz–5 kHz band, so mid extraction + band-pass +
  gentle multiband compression lifts the voice against the instrumental
  without any ML dependency.
- "vocals": Demucs stem separation, only when the `demucs` CLI is installed
  (it drags in PyTorch, so it stays optional). Best quality on dense mixes.
"""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

SAMPLE_RATE = 16_000

# Mid (center) extraction keeps what L and R share — normally the lead vocal —
# then band-pass to the voice range and even out the dynamics so quiet
# syllables survive. compand is deliberately gentle: over-compression smears
# consonants, which is exactly what we cannot afford here.
ENHANCE_FILTER = (
    "aformat=channel_layouts=stereo,"
    "pan=mono|c0=0.5*FL+0.5*FR,"
    "highpass=f=120,lowpass=f=5500,"
    "compand=attacks=0.02:decays=0.25:points=-70/-70|-35/-20|-20/-12|0/-6,"
    "loudnorm=I=-19:TP=-2:LRA=9"
)


class AudioPrepError(RuntimeError):
    pass


@dataclass
class AudioVariant:
    name: str
    path: Path
    description: str


def _run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        tail = "\n".join(proc.stderr.strip().splitlines()[-8:])
        raise AudioPrepError(f"command failed: {' '.join(cmd[:3])} …\n{tail}")


def ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None


def demucs_available() -> bool:
    return shutil.which("demucs") is not None


def probe_duration(path: Path) -> float | None:
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        return None
    proc = subprocess.run(
        [
            ffprobe,
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        capture_output=True,
        text=True,
    )
    try:
        return float(proc.stdout.strip())
    except ValueError:
        return None


def prepare_variants(
    source: Path,
    workdir: Path,
    *,
    enhance: bool = True,
    use_demucs: bool = False,
) -> list[AudioVariant]:
    """Decode `source` into one or more 16 kHz mono WAV variants under `workdir`."""
    if not ffmpeg_available():
        raise AudioPrepError(
            "ffmpeg is required. Install it first (macOS: `brew install ffmpeg`)."
        )
    if not source.exists():
        raise AudioPrepError(f"audio file not found: {source}")
    workdir.mkdir(parents=True, exist_ok=True)
    variants: list[AudioVariant] = []

    original = workdir / "original.wav"
    _run(
        [
            "ffmpeg", "-y", "-v", "error",
            "-i", str(source),
            "-ac", "1", "-ar", str(SAMPLE_RATE),
            str(original),
        ]
    )
    variants.append(AudioVariant("original", original, "plain 16 kHz mono decode"))

    if enhance:
        enhanced = workdir / "enhanced.wav"
        _run(
            [
                "ffmpeg", "-y", "-v", "error",
                "-i", str(source),
                "-af", ENHANCE_FILTER,
                "-ar", str(SAMPLE_RATE),
                str(enhanced),
            ]
        )
        variants.append(
            AudioVariant(
                "enhanced",
                enhanced,
                "center-channel extraction + voice band-pass + gentle compression",
            )
        )

    if use_demucs:
        if not demucs_available():
            raise AudioPrepError(
                "demucs was requested but the `demucs` CLI is not installed. "
                "Install with `pip install demucs` (pulls PyTorch) or drop --demucs."
            )
        vocals = _demucs_vocals(source, workdir)
        variants.append(AudioVariant("vocals", vocals, "Demucs two-stem vocal isolate"))

    return variants


def _demucs_vocals(source: Path, workdir: Path) -> Path:
    with tempfile.TemporaryDirectory(dir=workdir) as tmp:
        _run(
            [
                "demucs",
                "--two-stems", "vocals",
                "-o", tmp,
                str(source),
            ]
        )
        hits = sorted(Path(tmp).rglob("vocals.wav"))
        if not hits:
            raise AudioPrepError("demucs finished but produced no vocals.wav")
        out = workdir / "vocals.wav"
        _run(
            [
                "ffmpeg", "-y", "-v", "error",
                "-i", str(hits[0]),
                "-ac", "1", "-ar", str(SAMPLE_RATE),
                str(out),
            ]
        )
    return out
