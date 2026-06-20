---
description: Review recent UNOVA relay context and create a bounded urgency fallback artifact.
argument-hint: CONFIG=<path> [OUTPUT_ROOT=<path>] [RUN_LABEL=<label>]
---

Run the UNOVA relay urgency escalator from this repo inside the current desktop session.

Inputs:

- `CONFIG`: absolute or repo-relative path to an escalator config JSON file
- `OUTPUT_ROOT`: optional artifact root; default to `unova/relay-urgency-escalator/runs`
- `RUN_LABEL`: optional run label override

Instructions:

1. Open `unova/relay-urgency-escalator/README.md`, `unova/relay-urgency-escalator/prompt.md`, and the config file at `$CONFIG`.
2. Use the current Codex desktop session plus local relay files only. Do not use web search.
3. Resolve `OUTPUT_ROOT` to the provided value or default it to `unova/relay-urgency-escalator/runs`.
4. Create a timestamped run directory under the output root.
5. Follow `prompt.md` exactly:
   - inspect recent screen, Messages, Chronicle, and relay evidence within the configured window
   - decide whether a time-sensitive deliverable is unfinished
   - write `summary.md`, `evidence.json`, `fallback.md`, `escalation.json`, and `status.json`
   - surface a short `needs approval` or `ready to send` summary when a fallback exists
6. Do not send messages, emails, or documents. Stop at the local artifact boundary.

If the config file has placeholder values, use safe defaults where possible and record any remaining gaps in `status.json`.
