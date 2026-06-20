# UNOVA Chronicle Photo Memory

You are running a reusable Chronicle + Photos memory review inside the current Codex desktop session.

Use only:

- local Chronicle memory resources under `~/.codex/memories_extensions/chronicle/resources`
- live Chronicle recorder files under `$TMPDIR/chronicle/screen_recording`
- Computer Use tooling for the macOS Photos app
- local repo artifact files for this run

Do not use web search. Do not write to global Codex memory. Write local artifacts only.

## Goals

1. Confirm Chronicle freshness and Photos accessibility.
2. Review only the configured current-session surfaces.
3. Capture safe, high-signal notes about people and images.
4. Record consent and skip decisions explicitly.
5. Leave the human with a compact summary and next actions.

## Required order of operations

1. Read the config and resolve the output root.
2. Create a timestamped run directory under the output root and write:
   - `config.snapshot.json`
   - `run-metadata.json`
3. Chronicle checks:
   - verify Chronicle is running right now
   - compare the current UTC time against the latest Chronicle recorder files
   - inspect at most `review.sources.chronicle.max_recent_resource_files` recent Chronicle resource summaries
   - use Chronicle OCR only to find relevant windows or timestamps
4. Photos checks:
   - confirm the Photos app is available through Computer Use
   - inspect only the configured current-window surfaces
   - refresh app state before each turn that interacts with Photos
   - do not broad-crawl or deep-scroll beyond configured limits
5. Extraction:
   - create person notes only when the note remains safe under the consent rules
   - use config-provided aliases when present; otherwise use `person_unknown_<n>`
   - keep image notes focused on scene/theme/why-it-matters, not raw intimate detail
   - if a blocked category appears, do not describe it; create a skip entry instead
6. Write:
   - `summary.md`
   - `memory_artifacts.json`
   - `status.json`
7. Respond to the human with a compact status, artifact location, and next actions.

## Safety rules

- Never guess identity, age, relationship, intent, or emotion from a face alone.
- Never store explicit, intimate, medical, or minor-related image details.
- Never store precise addresses, contact info, account numbers, or identity-document text.
- Never dump raw Chronicle OCR into artifacts. If `allow_raw_ocr_quotes` is `false`, do not quote OCR at all.
- If `allow_raw_ocr_quotes` is `true`, quote only short non-sensitive product/UI text and keep excerpts under 12 words.
- Do not treat `Screenshots`, `Documents`, `Receipts`, or any other built-in Photos category as automatically safe. Check the visible surface first.
- If a Photos surface is dominated by blocked categories, stop deeper inspection there and record only a skip reason.
- Unknown people stay alias-only. Do not upgrade them to names unless the config explicitly allows user-supplied names and those names were actually supplied.
- Do not export, upload, share, or transmit images anywhere.

## Safe-note guidance

Safe person notes should stay high-level and useful:

- alias
- source reference
- non-sensitive recurring context
- why the note might matter later
- open question or follow-up gate

Safe image notes should stay high-level and useful:

- source reference
- generic scene summary
- non-sensitive tags
- why it matters to the current project or memory task
- sensitivity level

If an image is intimate or otherwise blocked, write a skip entry instead of an image note.

## Required local artifacts

Write these files exactly:

1. `summary.md`
2. `memory_artifacts.json`
3. `status.json`

### `summary.md`

Human-readable and compact. Include:

- Chronicle freshness result
- Photos accessibility result
- strongest safe notes
- skipped/withheld surfaces
- next actions

Keep it concise. Favor short bullets or short sections over narrative.

### `memory_artifacts.json`

Write valid JSON with this shape:

```json
{
  "run_id": "20260423-070000",
  "review_label": "current-session",
  "consent": {
    "basis": "Explicit user request in the current Codex session.",
    "people_label_mode": "alias_only",
    "allow_face_guessing": false,
    "allow_sensitive_image_details": false,
    "allow_global_memory_merge": false,
    "blocked_categories": [
      "nudity_or_intimate_imagery",
      "minors"
    ]
  },
  "source_checks": {
    "chronicle": {
      "running": true,
      "fresh": true,
      "latest_segment": "2026-04-23T12-02-11Z"
    },
    "photos_app": {
      "running": true,
      "window_title": "Library",
      "reviewed_targets": [
        "Library"
      ]
    }
  },
  "people_notes": [
    {
      "alias": "person_unknown_1",
      "source_refs": [
        "photos:Library:visible-3"
      ],
      "safe_high_signal_notes": [
        "Appears in the recent library view."
      ],
      "why_it_matters": "Possible future alias candidate if the user later approves naming.",
      "open_questions": [
        "Need a user-supplied alias before any durable merge."
      ]
    }
  ],
  "image_notes": [
    {
      "asset_ref": "photos:Library:visible-1",
      "safe_summary": "Mobile settings screenshot in the current library view.",
      "scene_tags": [
        "screenshot",
        "settings",
        "debug-context"
      ],
      "why_it_matters": "Useful as a lightweight anchor for recent work context.",
      "sensitivity": "low"
    }
  ],
  "skipped_items": [
    {
      "asset_ref": "photos:Library:visible-5",
      "reason": "Sensitive or blocked image category encountered; no detailed extraction recorded."
    }
  ],
  "next_actions": [
    "Provide user-approved aliases before any durable memory merge."
  ]
}
```

### `status.json`

Write valid JSON with this shape:

Allowed values:

- `status`: `completed`, `partial`, `skipped_sensitive`, `blocked_missing_consent`, `blocked_stale_chronicle`, `failed`

```json
{
  "run_id": "20260423-070000",
  "review_label": "current-session",
  "status": "completed",
  "summary": "Chronicle was fresh, Photos was accessible, safe notes were recorded, and sensitive surfaces were skipped.",
  "artifact_paths": {
    "summary_md": "/absolute/path/to/summary.md",
    "memory_artifacts_json": "/absolute/path/to/memory_artifacts.json",
    "status_json": "/absolute/path/to/status.json"
  },
  "source_checks": {
    "chronicle": {
      "running": true,
      "fresh": true
    },
    "photos_app": {
      "running": true,
      "accessible": true
    }
  },
  "counts": {
    "people_notes": 1,
    "image_notes": 1,
    "skipped_items": 1,
    "next_actions": 1
  },
  "safe_to_merge": false,
  "errors": []
}
```

Always write `status.json`, even when the run is blocked or partially skipped.

## Final response

After the files are written, respond briefly for the human reading the run. Mention:

- final status
- whether Chronicle was fresh
- whether Photos was accessible
- where the artifacts were written
- the top next action
