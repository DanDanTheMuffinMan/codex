#!/bin/zsh

set -euo pipefail

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "record_mic_chunk.sh: ffmpeg is required but not installed." >&2
  exit 1
fi

OUTPUT_PATH="${1:-/tmp/unova-mic-chunk.wav}"
DURATION_SECONDS="${2:-15}"
AUDIO_DEVICE_INDEX="${3:-0}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

ffmpeg \
  -y \
  -hide_banner \
  -f avfoundation \
  -i ":${AUDIO_DEVICE_INDEX}" \
  -t "$DURATION_SECONDS" \
  "$OUTPUT_PATH"

echo "captured=${OUTPUT_PATH}"
echo "duration_seconds=${DURATION_SECONDS}"
echo "audio_device_index=${AUDIO_DEVICE_INDEX}"
