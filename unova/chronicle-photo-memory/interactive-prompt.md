---
description: Review Chronicle + Photos context and write safe local memory artifacts.
argument-hint: CONFIG=<path> [OUTPUT_ROOT=<path>] [RUN_LABEL=<label>]
---

Run the repo's Chronicle photo-memory workflow from this repo inside the current desktop session.

Inputs:

- `CONFIG`: absolute or repo-relative path to the workflow config JSON
- `OUTPUT_ROOT`: optional artifact root; default `unova/chronicle-photo-memory/runs`
- `RUN_LABEL`: optional label appended to the timestamped run directory name

Instructions:

1. Open `unova/chronicle-photo-memory/README.md`, `unova/chronicle-photo-memory/prompt.md`, and the config file at `$CONFIG`.
2. Use the current session's Chronicle context and Computer Use access to the Photos app only. Do not use web search.
3. Resolve `OUTPUT_ROOT` to the provided value or default it to `unova/chronicle-photo-memory/runs`.
4. Create a timestamped run directory under the output root. If `RUN_LABEL` is provided, append a slug of that label; otherwise use a slug of `review.label` from the config.
5. Inside the run directory, write:
   - `config.snapshot.json`
   - `run-metadata.json`
   - `summary.md`
   - `memory_artifacts.json`
   - `status.json`
6. Maintain a `latest` symlink at the output root that points to the newest run directory.
7. Follow the safety and extraction rules from `unova/chronicle-photo-memory/prompt.md` exactly.
8. If the config still contains placeholder values such as `REPLACE_ME`, stop and say exactly what still needs to be filled in.
