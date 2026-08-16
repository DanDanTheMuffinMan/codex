# UNOVA Google Drive + Notion Sweep

This workflow turns the UNOVA Drive + Notion sweep into a repo-owned, rerunnable pass with:

- one config file for one or more accounts
- one `codex exec` run per configured account when batch mode works
- one interactive prompt path for the current Codex app session
- raw JSONL event capture for evidence
- local structured artifacts for each pass
- optional UNOVA source-cache persistence through `unova_spine`

## What it creates

Each run lands under `unova/google-drive-notion-sweep/runs/<timestamp>/`.

For each account, the runner saves:

- `account.json`: the exact account config used for that pass
- `run-metadata.json`: resolved paths and prompt metadata
- `prompt.md`: the full prompt sent to Codex
- `events.jsonl`: raw `codex exec --json` event stream
- `last_message.md`: the final assistant message
- `summary.md`: human-readable sweep summary written by the agent
- `evidence.json`: structured evidence written by the agent
- `status.json`: structured sweep status written by the agent

Each run also writes `manifest.json` at the run root plus a `latest` symlink.

## Account model

The current connector APIs expose one active Google Drive identity and one active Notion identity per run. This workflow still supports multiple accounts by:

- letting you define multiple account entries in one config
- verifying the active connector identity at the start of each pass
- writing an `account_mismatch` artifact when the observed account does not match the expected account

That means you can keep one reusable config, run the sweep repeatedly, and immediately see which account passes were valid and which need a connector switch before rerunning.

## Config

Start from [`config.example.json`](./config.example.json) and replace the placeholder values.

Important fields:

- `accounts[].label`: stable human label for the pass
- `accounts[].expected_google_drive_email`: expected email from Google Drive `get_profile`
- `accounts[].expected_notion_email`: expected email from Notion `get_users self`
- `accounts[].allow_account_mismatch`: if `false`, the sweep stops after identity verification on mismatch
- `accounts[].drive.folder_urls`: Google Drive folder URLs to enumerate
- `accounts[].drive.file_urls`: Drive/Docs/Sheets/Slides URLs to fetch directly
- `accounts[].notion.seed_queries`: Notion internal search queries
- `accounts[].notion.page_urls`: direct Notion page/database URLs or IDs to fetch
- `accounts[].notion.teamspace_ids`: optional teamspace filters for searches
- `accounts[].cache_tags`: tags added when persisting sources into `unova_spine`

## Run it

### Interactive app path

This is the most reliable path on this machine right now because the current desktop session already has the live connectors loaded.

Install the repo-owned prompt:

```bash
./scripts/install_unova_drive_notion_sweep_prompt.sh
```

Then restart Codex or open a new session and run:

```text
/prompts:unova-drive-notion-sweep CONFIG=/absolute/path/to/unova-sweep.json
```

Optional single-account rerun:

```text
/prompts:unova-drive-notion-sweep CONFIG=/absolute/path/to/unova-sweep.json ACCOUNT=primary
```

### Batch path with `codex exec`

Use this when your local `codex exec` can parse your MCP config and load the connectors in non-interactive mode.

Dry run first:

```bash
./scripts/run_unova_drive_notion_sweep.sh \
  --config unova/google-drive-notion-sweep/config.example.json \
  --dry-run
```

Real run:

```bash
./scripts/run_unova_drive_notion_sweep.sh \
  --config /absolute/path/to/unova-sweep.json
```

Single-account rerun:

```bash
./scripts/run_unova_drive_notion_sweep.sh \
  --config /absolute/path/to/unova-sweep.json \
  --account primary
```

Custom output root:

```bash
./scripts/run_unova_drive_notion_sweep.sh \
  --config /absolute/path/to/unova-sweep.json \
  --output-root /absolute/path/to/output/unova-drive-notion-sweep
```

## Evidence posture

The prompt is written to stay grounded:

- verify Google Drive + Notion identities first
- capture shared drives and search hits before summarizing
- prefer observed evidence over mythology or inference
- treat Drive fetch failures as evidence and try paired accessible docs before giving up
- persist meaningful fetched sources into `unova_spine` for later retrieval

## Notes

- The runner requires `codex` and `jq`.
- The sweep prompt intentionally uses the connectors you already have: Google Drive, Notion, and `unova_spine`.
- `runs/` is ignored via a local `.gitignore`, so repeated sweeps do not dirty the repo with artifacts you did not mean to commit.
- If `codex exec` fails before the sweep starts (for example with config parse errors such as `missing field command`), inspect `exec.stderr.log` in the account run folder and use the interactive prompt path while troubleshooting the local Codex config.
