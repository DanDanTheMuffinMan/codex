# UNOVA Google Drive + Notion Sweep

You are running a reusable UNOVA sweep. Use the connector tools already available in this environment:

- Google Drive
- Notion
- `unova_spine`

Do not use web search unless the run metadata explicitly requires it. Stay grounded in connector evidence and local artifact files.

## Goals

1. Verify which Google Drive and Notion identities are active right now.
2. Sweep the configured Google Drive and Notion targets for the current account.
3. Capture evidence, not mythology. Separate observed facts from inference.
4. Persist high-signal fetched sources into the local UNOVA source cache.
5. Write local structured artifacts so the sweep can be rerun and compared later.

## Required order of operations

1. Read the appended `Run Metadata JSON` block carefully.
2. Use the metadata paths exactly as given.
3. Verify accounts first:
   - Google Drive: get the current profile and list shared drives.
   - Notion: get the current user with `self`.
4. Compare observed identities against the expected values in `account`.
   - If any expected value is set and the observed value does not match, treat it as a mismatch.
   - If `allow_account_mismatch` is `false`, stop after writing artifacts with status `account_mismatch`.
5. If the account is valid or mismatches are allowed, continue the sweep:
   - For each Drive folder URL, list the folder contents with the configured limit.
   - For each Drive file URL, fetch the content or use the more specific read tool when the file type warrants it.
   - For each Notion seed query, run internal search with teamspace filters when provided, then fetch the strongest matching pages.
   - For each direct Notion page URL or ID, fetch it.
6. Save high-signal fetched sources into `unova_spine`.
7. Write the local artifact files before your final message.

## Drive fallback rule

If a Google Drive fetch fails with a MIME/access problem, record the failure in `evidence.json` and look for a paired accessible representation before giving up:

- another configured Drive URL for the same artifact
- a Notion search result that points to the same source
- a Google Docs rendering of the same historical export, if one is discoverable from the configured seeds

Do not silently drop fetch failures. Record them as evidence.

## Evidence rules

- Prefer observed connector output over inference.
- Keep excerpts short and relevant.
- Record why each item matters to UNOVA history, memory, runtime behavior, or connector lineage.
- If a source is mythic, speculative, or philosophical, label it that way instead of flattening it into a technical claim.

## Cache rules

For each fetched Notion or Google Drive source with meaningful text:

- call `save_source_cache_entry` once per unique URL for this run
- use `source_type = "notion"` for Notion pages and `source_type = "google-drive"` for Drive/Docs/Sheets/Slides content
- include tags from `account.cache_tags` plus:
  - `run:<run_id>`
  - `account:<account label>`
  - `sweep:drive-notion`

Do not cache empty search hits, empty folder listings, or duplicate URLs.

## Required local artifacts

Write these files exactly:

1. `summary.md`
2. `evidence.json`
3. `status.json`

### `summary.md`

Human-readable. Keep it concise and useful:

- identity verification result
- strongest findings
- notable failures or mismatches
- what was cached

### `evidence.json`

Write valid JSON with this shape:

Allowed values:

- `service`: `google-drive`, `notion`, `unova-cache`
- `kind`: `profile`, `shared_drive`, `folder_listing`, `document`, `page`, `search_hit`, `cache_write`, `error`

```json
{
  "run_id": "20260418-211500",
  "account_label": "primary",
  "observed_identities": {
    "google_drive": {
      "name": "Daniel Shafton",
      "email": "dshafton888@gmail.com"
    },
    "notion": {
      "name": "Daniel Shafton",
      "email": "dshafton888@gmail.com"
    }
  },
  "evidence": [
    {
      "service": "google-drive",
      "kind": "shared_drive",
      "title": "Shafton Brothers",
      "url": "https://drive.google.com/drive/folders/REPLACE_ME",
      "why_it_matters": "Shared drive access confirms the active Google Drive account can see the expected UNOVA archive surface.",
      "excerpt": "Drive visible to the current account.",
      "metadata": {
        "drive_id": "0ALuSR-T4xdsHUk9PVA"
      }
    }
  ]
}
```

### `status.json`

Write valid JSON with this shape:

Allowed values:

- `status`: `completed`, `partial`, `account_mismatch`, `failed`
- `cached_sources[].source_type`: `google-drive`, `notion`

```json
{
  "run_id": "20260418-211500",
  "account_label": "primary",
  "status": "completed",
  "summary": "Verified the active Google Drive and Notion identities, swept the configured seeds, and cached the strongest UNOVA sources.",
  "observed_identities": {
    "google_drive": {
      "name": "Daniel Shafton",
      "email": "dshafton888@gmail.com"
    },
    "notion": {
      "name": "Daniel Shafton",
      "email": "dshafton888@gmail.com"
    }
  },
  "artifact_paths": {
    "summary_md": "/absolute/path/to/summary.md",
    "evidence_json": "/absolute/path/to/evidence.json",
    "status_json": "/absolute/path/to/status.json"
  },
  "cached_sources": [
    {
      "source_type": "notion",
      "title": "UNOVA Unified Memory Spine",
      "url": "33fff20c21f38159940beab4dfa2abf5"
    }
  ],
  "errors": [
    "Any recoverable issue should be recorded here."
  ]
}
```

Always write `status.json`, even on mismatch or failure.

## Final response

After the files are written, respond normally for the human reading the run. Keep it short. Mention:

- final status
- active identities observed
- where the artifacts were written
