"""Run-folder outputs, following the unova runs/<timestamp>-<slug>/ convention.

Each run writes:

- lyrics.txt     clean reading copy; uncertain words marked [word?]
- lyrics.lrc     synced lyrics (line-level timestamps) for players that scroll
- lyrics.srt     subtitle form, handy for ear-checking in a video player
- report.md      human review sheet: flagged words with timestamps + what the
                 other passes heard instead
- report.json    full machine-readable record of every pass and every word
- reference.*    published lyrics, only when the lookup actually found some
"""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

from .consensus import ConsensusResult
from .metadata import ReferenceLyrics, TrackInfo


def make_run_dir(pack_root: Path, slug: str, now: dt.datetime | None = None) -> Path:
    now = now or dt.datetime.now()
    stamp = now.strftime("%Y%m%d-%H%M%S")
    run_dir = pack_root / "runs" / f"{stamp}-{slug}"
    run_dir.mkdir(parents=True, exist_ok=False)
    latest = pack_root / "runs" / "latest"
    try:
        if latest.is_symlink() or latest.exists():
            latest.unlink()
        latest.symlink_to(run_dir.name)
    except OSError:
        pass  # symlinks are a convenience; never fail the run over them
    return run_dir


def _fmt_ts(seconds: float) -> str:
    m, s = divmod(max(seconds, 0.0), 60)
    return f"{int(m):02d}:{s:05.2f}"


def _fmt_srt_ts(seconds: float) -> str:
    total_ms = int(round(max(seconds, 0.0) * 1000))
    h, rem = divmod(total_ms, 3_600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def write_outputs(
    run_dir: Path,
    track: TrackInfo,
    consensus: ConsensusResult,
    reference: ReferenceLyrics | None,
    *,
    audio_notes: list[dict],
    settings: dict,
) -> dict[str, Path]:
    written: dict[str, Path] = {}
    header = track.display()
    confidence = consensus.overall_confidence()
    flagged = consensus.flagged_words()

    # lyrics.txt — the reading copy
    txt_lines = [
        f"# {header}",
        f"# deciphered {dt.date.today().isoformat()} · primary pass {consensus.primary}"
        f" · overall confidence {confidence:.0%}",
        "# words marked [like this?] need an ear-check — see report.md",
        "",
    ]
    txt_lines += [line.marked_text() for line in consensus.lines]
    written["lyrics.txt"] = _write(run_dir / "lyrics.txt", "\n".join(txt_lines) + "\n")

    # lyrics.lrc — synced
    lrc_lines = [f"[ti:{track.title or 'unknown'}]"]
    if track.artist:
        lrc_lines.append(f"[ar:{track.artist}]")
    lrc_lines.append("[re:unova-lyric-decipher]")
    for line in consensus.lines:
        lrc_lines.append(f"[{_fmt_ts(line.start)}]{line.text}")
    written["lyrics.lrc"] = _write(run_dir / "lyrics.lrc", "\n".join(lrc_lines) + "\n")

    # lyrics.srt — for ear-checking in a video/audio player
    srt_chunks = []
    for i, line in enumerate(consensus.lines, 1):
        srt_chunks.append(
            f"{i}\n{_fmt_srt_ts(line.start)} --> {_fmt_srt_ts(line.end)}\n{line.marked_text()}\n"
        )
    written["lyrics.srt"] = _write(run_dir / "lyrics.srt", "\n".join(srt_chunks))

    # report.md — the human review sheet
    md = [
        f"# Decipher report — {header}",
        "",
        f"- overall confidence: **{confidence:.0%}**",
        f"- primary pass: `{consensus.primary}`",
        f"- passes run: {len(consensus.passes)}",
        f"- words flagged for ear-check: {len(flagged)} / {len(consensus.words)}",
    ]
    if reference:
        md.append(
            f"- published lyrics: **found on {reference.source}** — saved as reference; "
            "compare before trusting the transcription"
        )
    else:
        md.append("- published lyrics: none found (lookup came back empty)")
    md += ["", "## Passes", ""]
    md.append("| pass | detected language | avg word confidence |")
    md.append("|---|---|---|")
    for p in consensus.passes:
        md.append(f"| `{p.name}` | {p.language} ({p.language_prob:.0%}) | {p.score():.0%} |")
    md += ["", "## Words to ear-check", ""]
    if flagged:
        md.append("| time | heard | conf | agreement | other passes heard |")
        md.append("|---|---|---|---|---|")
        for cw in flagged:
            alts = ", ".join(f"“{t}”×{n}" for t, n in cw.alternatives) or "—"
            md.append(
                f"| {_fmt_ts(cw.word.start)} | **{cw.word.text}** | {cw.word.prob:.0%} "
                f"| {cw.agreement:.0%} of {cw.votes} | {alts} |"
            )
        md += [
            "",
            "Open the audio at each timestamp (lyrics.srt loads straight into a video "
            "player) and settle these by ear; then edit lyrics.txt in place.",
        ]
    else:
        md.append("Nothing flagged — every word cleared confidence and agreement checks.")
    written["report.md"] = _write(run_dir / "report.md", "\n".join(md) + "\n")

    # report.json — everything, machine-readable
    payload = {
        "track": {
            "title": track.title,
            "artist": track.artist,
            "spotify_url": track.spotify_url,
            "metadata_source": track.source,
        },
        "settings": settings,
        "audio_variants": audio_notes,
        "overall_confidence": confidence,
        "primary_pass": consensus.primary,
        "reference_lyrics_found": bool(reference),
        "passes": [
            {
                "name": p.name,
                "variant": p.variant,
                "config": p.config,
                "language": p.language,
                "language_probability": p.language_prob,
                "score": p.score(),
                "lines": [
                    {
                        "start": line.start,
                        "end": line.end,
                        "text": line.text,
                        "avg_logprob": line.avg_logprob,
                        "no_speech_prob": line.no_speech_prob,
                        "words": [
                            {"start": w.start, "end": w.end, "text": w.text, "prob": w.prob}
                            for w in line.words
                        ],
                    }
                    for line in p.lines
                ],
            }
            for p in consensus.passes
        ],
        "consensus": [
            {
                "start": line.start,
                "end": line.end,
                "text": line.text,
                "words": [
                    {
                        "text": cw.word.text,
                        "start": cw.word.start,
                        "end": cw.word.end,
                        "prob": cw.word.prob,
                        "agreement": cw.agreement,
                        "votes": cw.votes,
                        "flagged": cw.flagged,
                        "alternatives": [{"text": t, "count": n} for t, n in cw.alternatives],
                    }
                    for cw in line.words
                ],
            }
            for line in consensus.lines
        ],
    }
    written["report.json"] = _write(
        run_dir / "report.json", json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    )

    if reference:
        if reference.synced:
            written["reference.lrc"] = _write(run_dir / "reference.lrc", reference.synced + "\n")
        if reference.plain:
            written["reference.txt"] = _write(run_dir / "reference.txt", reference.plain + "\n")
    return written


def write_reference_only(run_dir: Path, track: TrackInfo, reference: ReferenceLyrics) -> dict[str, Path]:
    written: dict[str, Path] = {}
    if reference.synced:
        written["reference.lrc"] = _write(run_dir / "reference.lrc", reference.synced + "\n")
    if reference.plain:
        written["reference.txt"] = _write(run_dir / "reference.txt", reference.plain + "\n")
    note = {
        "track": {"title": track.title, "artist": track.artist, "spotify_url": track.spotify_url},
        "reference": {"source": reference.source, **reference.detail,
                      "instrumental": reference.instrumental},
    }
    written["report.json"] = _write(
        run_dir / "report.json", json.dumps(note, indent=2, ensure_ascii=False) + "\n"
    )
    return written


def _write(path: Path, content: str) -> Path:
    path.write_text(content, encoding="utf-8")
    return path
