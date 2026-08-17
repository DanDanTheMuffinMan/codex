"""Multi-pass Whisper transcription via faster-whisper.

One "pass" = one prepared audio variant transcribed under one decode config.
Passes differ on purpose: sung vocals are far off Whisper's training
distribution, so different variants/configs fail in *different* places, and
the consensus stage exploits that disagreement to find the uncertain words.

faster-whisper is imported lazily so the offline unit tests and `--lookup-only`
runs never need the dependency.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from .audio import AudioVariant


@dataclass
class Word:
    start: float
    end: float
    text: str
    prob: float

    @property
    def mid(self) -> float:
        return (self.start + self.end) / 2


@dataclass
class Line:
    start: float
    end: float
    text: str
    words: list[Word] = field(default_factory=list)
    avg_logprob: float = 0.0
    no_speech_prob: float = 0.0


@dataclass
class PassResult:
    name: str
    variant: str
    config: str
    language: str
    language_prob: float
    lines: list[Line] = field(default_factory=list)

    @property
    def words(self) -> list[Word]:
        return [w for line in self.lines for w in line.words]

    def score(self) -> float:
        """Mean word probability, weighted by word duration; 0 when empty."""
        words = self.words
        if not words:
            return 0.0
        total_dur = sum(max(w.end - w.start, 0.05) for w in words)
        return sum(w.prob * max(w.end - w.start, 0.05) for w in words) / total_dur


@dataclass
class DecodeConfig:
    name: str
    beam_size: int = 5
    temperature: float | tuple[float, ...] = 0.0
    condition_on_previous_text: bool = True


DEFAULT_CONFIGS = [
    DecodeConfig("beam5", beam_size=5, temperature=0.0),
    DecodeConfig("beam8-nocond", beam_size=8, temperature=0.0, condition_on_previous_text=False),
    DecodeConfig("sample", beam_size=1, temperature=(0.2, 0.4, 0.6)),
]

# Passes: every variant gets the solid beam pass; the best-quality variant
# (last in the prepared list — vocals > enhanced > original) also gets the
# alternate configs so disagreement data concentrates where audio is cleanest.


def build_passes(variants: list[AudioVariant], extra_configs: int) -> list[tuple[AudioVariant, DecodeConfig]]:
    plan: list[tuple[AudioVariant, DecodeConfig]] = []
    for variant in variants:
        plan.append((variant, DEFAULT_CONFIGS[0]))
    best = variants[-1]
    for cfg in DEFAULT_CONFIGS[1 : 1 + max(extra_configs, 0)]:
        plan.append((best, cfg))
    return plan


def run_passes(
    variants: list[AudioVariant],
    *,
    model_size: str = "small",
    language: str | None = None,
    extra_configs: int = 2,
    initial_prompt: str | None = None,
    device: str = "auto",
    compute_type: str = "auto",
    progress=lambda msg: None,
) -> list[PassResult]:
    from faster_whisper import WhisperModel

    progress(f"loading Whisper model '{model_size}' ({device}/{compute_type})")
    model = WhisperModel(model_size, device=device, compute_type=compute_type)

    results: list[PassResult] = []
    plan = build_passes(variants, extra_configs)
    for i, (variant, cfg) in enumerate(plan, 1):
        progress(f"pass {i}/{len(plan)}: {variant.name} × {cfg.name}")
        segments, info = model.transcribe(
            str(variant.path),
            language=language,
            beam_size=cfg.beam_size,
            temperature=cfg.temperature,
            condition_on_previous_text=cfg.condition_on_previous_text,
            word_timestamps=True,
            vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 350},
            initial_prompt=initial_prompt,
        )
        lines: list[Line] = []
        for seg in segments:
            # faster-whisper hands back numpy scalars; coerce to native types
            # here so everything downstream (json included) stays plain Python.
            words = [
                Word(start=float(w.start), end=float(w.end),
                     text=w.word.strip(), prob=float(w.probability))
                for w in (seg.words or [])
                if w.word.strip()
            ]
            lines.append(
                Line(
                    start=float(seg.start),
                    end=float(seg.end),
                    text=seg.text.strip(),
                    words=words,
                    avg_logprob=float(seg.avg_logprob),
                    no_speech_prob=float(seg.no_speech_prob),
                )
            )
        results.append(
            PassResult(
                name=f"{variant.name}/{cfg.name}",
                variant=variant.name,
                config=cfg.name,
                language=info.language,
                language_prob=info.language_probability,
                lines=lines,
            )
        )
    return results


def save_pass_audio_note(variants: list[AudioVariant]) -> list[dict]:
    return [
        {"name": v.name, "file": v.path.name, "description": v.description}
        for v in variants
    ]
