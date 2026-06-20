---
description: Run the repo's UNOVA Google Drive + Notion sweep from a config file in the current session.
argument-hint: CONFIG=<path> [ACCOUNT=<label>] [OUTPUT_ROOT=<path>]
---

Run the UNOVA Google Drive + Notion sweep from this repo inside the current session.

Inputs:

- `CONFIG`: absolute or repo-relative path to a sweep config JSON file
- `ACCOUNT`: optional account label; if provided, only run that account
- `OUTPUT_ROOT`: optional artifact root; default to `unova/google-drive-notion-sweep/runs`

Instructions:

1. Open `unova/google-drive-notion-sweep/README.md`, `unova/google-drive-notion-sweep/prompt.md`, and the config file at `$CONFIG`.
2. Use the current session's Google Drive, Notion, and `unova_spine` connectors only.
3. If `ACCOUNT` is set, run only that account. Otherwise run all enabled accounts.
4. Create a timestamped run directory under `OUTPUT_ROOT` or the default root.
5. For each selected account:
   - verify Google Drive and Notion identities first
   - record account mismatches instead of hand-waving them
   - write `summary.md`, `evidence.json`, and `status.json`
   - save high-signal fetched sources into `unova_spine`
6. Write a run-level `manifest.json` after the account passes finish.
7. Keep the work evidence-driven and concise.

If the config file has placeholder values, stop and say exactly what still needs to be filled in.
