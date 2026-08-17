# UNOVA Lyric Decipher

A local bot for deciphering lyrics that are genuinely hard to hear and not
published anywhere — mumbled vocals, tiny artists, unreleased mixes.

It takes an audio file you already have, checks whether the lyrics are in fact
already published (LRCLIB), and if not, runs a multi-pass transcription
pipeline that is honest about uncertainty: every word the passes disagreed on
is flagged with a timestamp and the alternatives, so you ear-check seconds,
not the whole song.

## How it works

1. **Metadata** — paste a Spotify track link and the pack resolves the display
   title via the public oEmbed endpoint (no login, no audio). Or pass
   `--title/--artist` yourself.
2. **Published-lyrics check** — searches LRCLIB, the open lyrics database. If
   someone already transcribed the song, that's saved as `reference.*` and you
   just saved yourself the work.
3. **Audio variants** — ffmpeg decodes the file and builds a vocal-focused
   variant (center-channel extraction + voice band-pass + gentle compression).
   With `--demucs` installed you also get a true ML vocal stem.
4. **Multi-pass Whisper** — each variant is transcribed with word-level
   timestamps; the best variant gets extra decode configs (different beam
   sizes / temperatures). Sung vocals make ASR fail in *different* places per
   pass, which is exactly the signal we want.
5. **Consensus** — the strongest pass provides the structure; every word is
   cross-checked against the other passes by time overlap. Confident + agreed
   words are trusted; the rest are marked `[like this?]` with alternatives in
   the report.

## Setup (macOS)

```bash
brew install ffmpeg
pip install -r unova/lyric-decipher/requirements.txt
```

Optional, best vocal isolation for dense mixes (pulls PyTorch):

```bash
pip install demucs
```

## Usage

```bash
# the track that started this pack — him's "Chateau (elan)":
python3 unova/lyric-decipher/decipher.py ~/Music/chateau-elan.m4a \
  --spotify-url "https://open.spotify.com/track/7ewmdNM0LTB9MMomRmtFQY" \
  --artist "him's"

# quick check whether lyrics are already published, no transcription:
python3 unova/lyric-decipher/decipher.py --lookup-only --title "Chateau (elan)" --artist "him's"

# harder mixes: bigger model + vocal stem + a genre hint for the decoder
python3 unova/lyric-decipher/decipher.py song.flac --model medium --demucs \
  --prompt "indie bedroom pop, hushed male vocal"
```

Useful flags: `--language en` when autodetect guesses wrong, `--model`
(`tiny`→`large-v3`; `small` is the speed/quality sweet spot on CPU),
`--extra-passes 0` for a fast single-config run, `--no-enhance`,
`--skip-lookup`. Defaults can live in `config.json` (copy
`config.example.json`).

## Outputs

Each run lands in `unova/lyric-decipher/runs/<timestamp>-<slug>/` (with a
`latest` symlink):

- `lyrics.txt` — reading copy, uncertain words marked `[word?]`
- `lyrics.lrc` — synced lyrics for players that scroll
- `lyrics.srt` — load next to the audio in a video player to ear-check
  flagged moments at the exact second
- `report.md` — review sheet: pass table, and every flagged word with its
  timestamp, confidence, agreement, and what other passes heard
- `report.json` — every pass, line, word, and probability, machine-readable
- `reference.txt` / `reference.lrc` — only when published lyrics were found

The intended loop: run the pack, open `report.md`, ear-check the handful of
flagged timestamps with `lyrics.srt` loaded in a player, correct
`lyrics.txt`, done.

## Scope and sources

- Works on audio files you already have: purchases, DRM-free downloads
  (Bandcamp etc.), your own recordings. It does **not** download audio from
  Spotify or other streaming services — the Spotify link is used only to
  resolve the track title.
- Output is for your own listening/reference. Deciphered transcriptions of
  someone else's song aren't yours to republish.

## Smoke test

`smoke/run_smoke.sh` synthesizes a fake "song" (espeak-ng vocal over a
generated instrumental bed), runs the full pipeline on it with the `tiny`
model, and checks that known words come through. Needs ffmpeg + espeak-ng +
faster-whisper; first run downloads the tiny model (~75 MB).

Offline unit tests (no model, no network):

```bash
python3 -m pytest unova/lyric-decipher/tests
```
