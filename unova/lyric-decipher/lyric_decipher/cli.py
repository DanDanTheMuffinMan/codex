"""Command-line entry point.

    python3 decipher.py song.m4a --spotify-url https://open.spotify.com/track/…

Works on a local audio file you already have (purchase, DRM-free download,
your own recording). It never downloads audio from streaming services.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

from . import __version__
from .audio import AudioPrepError, prepare_variants, probe_duration
from .consensus import build_consensus
from .metadata import TrackInfo, lookup_published_lyrics, resolve_spotify_track
from .output import make_run_dir, write_outputs, write_reference_only
from .transcribe import run_passes, save_pass_audio_note

PACK_ROOT = Path(__file__).resolve().parent.parent


def load_config(path: Path | None) -> dict:
    candidates = [path] if path else [PACK_ROOT / "config.json"]
    for cand in candidates:
        if cand and cand.exists():
            try:
                return json.loads(cand.read_text())
            except json.JSONDecodeError as exc:
                raise SystemExit(f"config {cand} is not valid JSON: {exc}")
    return {}


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="lyric-decipher",
        description="Decipher hard-to-hear lyrics from an audio file you already have.",
    )
    p.add_argument("audio", nargs="?", type=Path, help="path to the audio file")
    p.add_argument("--spotify-url", help="Spotify track link, used only to resolve title metadata")
    p.add_argument("--title", help="track title (overrides anything resolved)")
    p.add_argument("--artist", help="artist name (overrides anything resolved)")
    p.add_argument("--language", help="ISO language hint, e.g. en, ja (default: autodetect)")
    p.add_argument("--model", help="Whisper size: tiny/base/small/medium/large-v3 (default small)")
    p.add_argument("--extra-passes", type=int, default=None,
                   help="extra decode configs on the best variant, 0-2 (default 2)")
    p.add_argument("--prompt", help="style/vocabulary hint passed to the model "
                                    "(e.g. song genre, artist spellings)")
    p.add_argument("--no-enhance", action="store_true", help="skip the vocal-focus filter variant")
    p.add_argument("--demucs", action="store_true",
                   help="add a Demucs vocal-stem variant (requires `pip install demucs`)")
    p.add_argument("--skip-lookup", action="store_true",
                   help="don't check LRCLIB for already-published lyrics")
    p.add_argument("--lookup-only", action="store_true",
                   help="only check for published lyrics; no transcription")
    p.add_argument("--config", type=Path, help="path to config.json (default: pack root)")
    p.add_argument("--out-root", type=Path, help="where runs/ lives (default: this pack)")
    p.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    cfg = load_config(args.config)

    model_size = args.model or cfg.get("model", "small")
    extra = args.extra_passes if args.extra_passes is not None else int(cfg.get("extra_passes", 2))
    language = args.language or cfg.get("language")
    enhance = not args.no_enhance and cfg.get("enhance", True)
    use_demucs = args.demucs or bool(cfg.get("demucs", False))
    pack_root = args.out_root or Path(cfg.get("out_root", PACK_ROOT))

    # --- metadata -----------------------------------------------------------
    track = TrackInfo()
    if args.spotify_url:
        resolved = resolve_spotify_track(args.spotify_url)
        if resolved:
            track = resolved
            print(f"resolved track: {track.display()}")
        else:
            print("warning: could not resolve the Spotify link; continuing without it",
                  file=sys.stderr)
            track.spotify_url = args.spotify_url
    if args.title:
        track.title = args.title
    if args.artist:
        track.artist = args.artist
    if not track.title and args.audio is not None:
        track.title = args.audio.stem

    # --- published-lyrics check --------------------------------------------
    reference = None
    if not args.skip_lookup and track.title:
        reference = lookup_published_lyrics(track)
        if reference:
            who = reference.detail.get("artistName") or "?"
            what = reference.detail.get("trackName") or track.title
            print(f"published lyrics found on LRCLIB: “{what}” by {who} — saving as reference")
            if reference.instrumental:
                print("note: LRCLIB marks this track as instrumental")
        else:
            print("no published lyrics found — deciphering from audio")

    if args.lookup_only:
        if not reference:
            print("lookup-only: nothing published for this track; run again with an "
                  "audio file to transcribe it")
            return 1
        run_dir = make_run_dir(pack_root, track.slug())
        write_reference_only(run_dir, track, reference)
        print(f"reference lyrics saved under {run_dir}")
        return 0

    # --- transcription ------------------------------------------------------
    if args.audio is None:
        print("error: an audio file is required unless --lookup-only is used", file=sys.stderr)
        return 2
    if not args.audio.exists():
        print(f"error: audio file not found: {args.audio}", file=sys.stderr)
        return 2

    duration = probe_duration(args.audio)
    if duration:
        print(f"audio: {args.audio.name} ({duration:.0f}s)")

    with tempfile.TemporaryDirectory(prefix="lyric-decipher-") as tmp:
        try:
            variants = prepare_variants(
                args.audio, Path(tmp), enhance=enhance, use_demucs=use_demucs
            )
        except AudioPrepError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2
        print("prepared variants: " + ", ".join(v.name for v in variants))

        passes = run_passes(
            variants,
            model_size=model_size,
            language=language,
            extra_configs=extra,
            initial_prompt=args.prompt or cfg.get("prompt"),
            device=cfg.get("device", "auto"),
            compute_type=cfg.get("compute_type", "auto"),
            progress=lambda msg: print(f"  {msg}"),
        )
        audio_notes = save_pass_audio_note(variants)

    non_empty = [p for p in passes if p.words]
    if not non_empty:
        print("error: no pass produced any words — is there singing in this file? "
              "Try --model medium, or --demucs for a dense mix.", file=sys.stderr)
        return 1

    consensus = build_consensus(non_empty)
    run_dir = make_run_dir(pack_root, track.slug())
    written = write_outputs(
        run_dir,
        track,
        consensus,
        reference,
        audio_notes=audio_notes,
        settings={
            "model": model_size,
            "language": language or "auto",
            "extra_passes": extra,
            "enhance": enhance,
            "demucs": use_demucs,
            "version": __version__,
        },
    )

    flagged = consensus.flagged_words()
    print()
    print(f"deciphered {len(consensus.words)} words across {len(consensus.lines)} lines "
          f"· overall confidence {consensus.overall_confidence():.0%}")
    if flagged:
        print(f"{len(flagged)} word(s) need an ear-check — see report.md")
    print("outputs:")
    for name, path in written.items():
        print(f"  {name}: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
