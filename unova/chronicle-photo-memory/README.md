# UNOVA Chronicle Photo Memory

This workflow turns live Chronicle + Photos review into a repo-owned, repeatable pass that:

- uses only the current Codex desktop session's Chronicle and Computer Use context
- writes local artifacts instead of mutating global memory
- keeps people notes alias-first and consent-aware
- records skip decisions for sensitive imagery instead of flattening it into memory
- leaves a compact summary plus next actions after each pass

## What it creates

Each run lands under `unova/chronicle-photo-memory/runs/<timestamp>-<label>/`.

The workflow writes:

- `config.snapshot.json`: exact config used for the run
- `run-metadata.json`: resolved paths plus run settings
- `summary.md`: compact human-readable summary and next actions
- `memory_artifacts.json`: structured safe notes, skips, and consent snapshot
- `status.json`: machine-readable run outcome and counts

The run root also updates a `latest` symlink for easy reruns and comparison.

## Why the workflow is interactive

This pack depends on live session facts:

- whether Chronicle is running right now
- whether recent Chronicle frames are fresh right now
- what the Photos app is showing right now

Because those surfaces belong to the active Codex desktop session, the supported path is an interactive slash prompt rather than a blind `codex exec` batch run.

## Config

Start from [`config.example.json`](./config.example.json).

Important fields:

- `review.label`: stable label used in the run directory name
- `review.sources.chronicle.*`: Chronicle freshness and search limits
- `review.sources.photos_app.*`: allowed Photos surfaces and inspection limits
- `review.consent.*`: the allowed note posture for the run
- `review.known_people[]`: optional alias-only roster for safe person labeling
- `review.artifact_rules.*`: caps for people notes, image notes, and next actions

The safe default posture is intentionally conservative:

- alias-only people notes
- no face guessing
- no raw OCR dumping
- no intimate or sensitive image details
- no automatic merge into global memory

## Run it

Install the repo-owned prompt:

```bash
./scripts/install_unova_chronicle_photo_memory_prompt.sh
```

Then restart Codex or open a new session and run:

```text
/prompts:unova-chronicle-photo-memory CONFIG=/absolute/path/to/chronicle-photo-memory.json
```

Optional overrides:

```text
/prompts:unova-chronicle-photo-memory CONFIG=/absolute/path/to/chronicle-photo-memory.json OUTPUT_ROOT=/absolute/path/to/output RUN_LABEL=apr23-review
```

## Safety posture

The protocol is written to stay boring and trustworthy:

- verify Chronicle is live and fresh before using it
- use Chronicle OCR only for search and scoping, not for durable extraction
- inspect only the configured Photos surfaces in the current window
- do not assume built-in Photos buckets like `Screenshots` or `Documents` are automatically safe
- do not guess names, ages, or relationships
- do not persist explicit, intimate, medical, minor, document, financial, or contact-info details
- when sensitive imagery appears, record a skip reason and move on
- keep the final summary compact and action-oriented

## Notes

- The workflow writes local repo artifacts only. It does not update `~/.codex/memories` or any other durable memory store.
- If you want future durable memory merges, review `memory_artifacts.json` first and make that an explicit follow-up decision.
- A built-in Photos category can still be mixed or sensitive. A user-curated safe album or selection is the best rerun target when you want deeper extraction.
