#!/usr/bin/env bash
# End-to-end smoke test on synthetic audio — no copyrighted material involved.
# Needs: ffmpeg, espeak-ng, faster-whisper (downloads the tiny model on first run).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="${LYRIC_DECIPHER_SMOKE_DIR:-${TMPDIR:-/tmp}/lyric-decipher-smoke}"
rm -rf "$work"
mkdir -p "$work"

vocal_text="golden hour fades away while shadows dance across the water"

echo "== synthesizing test song =="
espeak-ng -v en-us -s 130 -p 55 -w "$work/vocal.wav" "$vocal_text"

# Instrumental bed: an A-minor-ish drone plus brown noise, quiet enough that
# the tiny model still has a fighting chance, loud enough to be a real mix.
ffmpeg -y -v error \
  -f lavfi -i "sine=frequency=220:duration=12" \
  -f lavfi -i "sine=frequency=261.63:duration=12" \
  -f lavfi -i "sine=frequency=329.63:duration=12" \
  -f lavfi -i "anoisesrc=colour=brown:duration=12:amplitude=0.25" \
  -filter_complex "amix=inputs=4:normalize=1" "$work/bed.wav"

ffmpeg -y -v error -i "$work/vocal.wav" -i "$work/bed.wav" -filter_complex \
  "[0]adelay=1200|1200[v];[1]volume=0.30[b];[v][b]amix=inputs=2:duration=first:normalize=0" \
  -ac 2 "$work/song.wav"

echo "== running the pipeline (tiny model) =="
python3 "$here/../decipher.py" "$work/song.wav" \
  --title "Smoke Test Song" --model tiny --language en \
  --skip-lookup --out-root "$work"

echo "== checking output =="
python3 "$here/check_smoke.py" "$work" "$vocal_text"
echo "smoke test passed"
