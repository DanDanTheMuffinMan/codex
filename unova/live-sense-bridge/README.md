# UNOVA Live Sense Bridge

This is a lightweight local bridge for the parts of "watch and work" that the current Codex desktop session does not already cover.

What already exists:

- screen context and recent screen history via Chronicle
- quiet proactive follow-up in this thread via the `Chronicle Watch` heartbeat
- Computer Use for app-level clicking and typing

What this folder adds:

- a repo-owned webcam probe that can request camera access and save a fresh frame locally
- a repo-owned mic recorder that can save a local audio chunk from the default microphone

## Webcam probe

List the cameras visible to AVFoundation:

```bash
swift unova/live-sense-bridge/capture_webcam_frame.swift --list
```

Capture one frame from the default camera:

```bash
swift unova/live-sense-bridge/capture_webcam_frame.swift \
  --output /tmp/unova-webcam-frame.jpg
```

Capture one frame from a specific device:

```bash
swift unova/live-sense-bridge/capture_webcam_frame.swift \
  --device "FaceTime HD Camera" \
  --output /tmp/unova-webcam-frame.jpg
```

If macOS shows a camera permission prompt for Terminal, approve it. The script will fail loudly if the permission is denied or the frame never arrives.

## Current operating model

- Screen: use Chronicle as the live screen source of truth.
- Webcam: use `capture_webcam_frame.swift` to prove and refresh camera access.
- Calls and meetings: record a local mic chunk first, then choose an explicit transcription path.

## Mic chunk recorder

Record 15 seconds from the default microphone:

```bash
zsh unova/live-sense-bridge/record_mic_chunk.sh \
  /tmp/unova-mic-chunk.wav \
  15
```

Record 30 seconds from a different audio device index:

```bash
zsh unova/live-sense-bridge/record_mic_chunk.sh \
  /tmp/unova-mic-chunk.wav \
  30 \
  1
```

## Notes

- This bridge writes local files only.
- It does not update durable Codex memory by itself.
- Be deliberate with calls and meetings: if other people are involved, make sure you have the right notice and consent before routing audio into a transcript workflow.
