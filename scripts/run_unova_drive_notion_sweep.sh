#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_unova_drive_notion_sweep.sh [options]

Runs a config-driven UNOVA Google Drive + Notion sweep via `codex exec`,
capturing raw event logs plus local structured artifacts for each account.

Options:
  -c, --config PATH        Config JSON path.
  -o, --output-root PATH   Output root for run artifacts.
      --account LABEL      Only run the matching account label.
      --dry-run            Generate prompts/metadata only; do not execute Codex.
  -h, --help               Show this help.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

slugify() {
  local raw="$1"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  raw="$(printf '%s' "$raw" | tr -cs 'a-z0-9' '-')"
  raw="${raw#-}"
  raw="${raw%-}"
  if [[ -z "$raw" ]]; then
    raw="account"
  fi
  printf '%s' "$raw"
}

write_fallback_status() {
  local status_path="$1"
  local evidence_path="$2"
  local run_id="$3"
  local account_label="$4"
  local status="$5"
  local summary="$6"
  local summary_path="$7"
  local errors_json="$8"

  jq -n \
    --arg run_id "$run_id" \
    --arg account_label "$account_label" \
    --arg status "$status" \
    --arg summary "$summary" \
    --arg summary_path "$summary_path" \
    --arg evidence_path "$evidence_path" \
    --arg status_path "$status_path" \
    --argjson errors "$errors_json" \
    '{
      run_id: $run_id,
      account_label: $account_label,
      status: $status,
      summary: $summary,
      observed_identities: {
        google_drive: {
          name: null,
          email: null
        },
        notion: {
          name: null,
          email: null
        }
      },
      artifact_paths: {
        summary_md: $summary_path,
        evidence_json: $evidence_path,
        status_json: $status_path
      },
      cached_sources: [],
      errors: $errors
    }' > "$status_path"

  jq -n \
    --arg run_id "$run_id" \
    --arg account_label "$account_label" \
    '{
      run_id: $run_id,
      account_label: $account_label,
      observed_identities: {
        google_drive: {
          name: null,
          email: null
        },
        notion: {
          name: null,
          email: null
        }
      },
      evidence: []
    }' > "$evidence_path"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_ROOT="$REPO_ROOT/unova/google-drive-notion-sweep"
PROMPT_TEMPLATE="$WORKFLOW_ROOT/prompt.md"
DEFAULT_CONFIG="$WORKFLOW_ROOT/config.example.json"

CONFIG_PATH="$DEFAULT_CONFIG"
OUTPUT_ROOT="$WORKFLOW_ROOT/runs"
ACCOUNT_FILTER=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config)
      [[ $# -ge 2 ]] || fail "--config requires a value"
      CONFIG_PATH="$2"
      shift 2
      ;;
    -o|--output-root)
      [[ $# -ge 2 ]] || fail "--output-root requires a value"
      OUTPUT_ROOT="$2"
      shift 2
      ;;
    --account)
      [[ $# -ge 2 ]] || fail "--account requires a value"
      ACCOUNT_FILTER="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ "$CONFIG_PATH" != /* ]]; then
  CONFIG_PATH="$REPO_ROOT/$CONFIG_PATH"
fi

if [[ "$OUTPUT_ROOT" != /* ]]; then
  OUTPUT_ROOT="$REPO_ROOT/$OUTPUT_ROOT"
fi

[[ -f "$PROMPT_TEMPLATE" ]] || fail "missing prompt template: $PROMPT_TEMPLATE"
[[ -f "$CONFIG_PATH" ]] || fail "missing config file: $CONFIG_PATH"

require_cmd codex
require_cmd jq

jq -e '.accounts | type == "array" and length > 0' "$CONFIG_PATH" >/dev/null \
  || fail "config must contain a non-empty accounts array"

DUPLICATE_LABELS="$(jq -r '.accounts[].label' "$CONFIG_PATH" | sort | uniq -d || true)"
if [[ -n "$DUPLICATE_LABELS" ]]; then
  fail "config contains duplicate account labels: $DUPLICATE_LABELS"
fi

ACCOUNT_QUERY='.accounts[] | select(.enabled != false)'
if [[ -n "$ACCOUNT_FILTER" ]]; then
  ACCOUNT_QUERY="$ACCOUNT_QUERY | select(.label == \$label)"
  ACCOUNT_COUNT="$(jq -r --arg label "$ACCOUNT_FILTER" "[${ACCOUNT_QUERY}] | length" "$CONFIG_PATH")"
else
  ACCOUNT_COUNT="$(jq -r "[${ACCOUNT_QUERY}] | length" "$CONFIG_PATH")"
fi

[[ "$ACCOUNT_COUNT" != "0" ]] || fail "no enabled accounts matched the current selection"

RUN_ID="$(date '+%Y%m%d-%H%M%S')"
GENERATED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
RUN_ROOT="$OUTPUT_ROOT/$RUN_ID"

mkdir -p "$RUN_ROOT"
cp "$CONFIG_PATH" "$RUN_ROOT/config.snapshot.json"
ln -sfn "$RUN_ROOT" "$OUTPUT_ROOT/latest"

declare -a STATUS_FILES

while IFS= read -r ACCOUNT_JSON; do
  ACCOUNT_LABEL="$(jq -r '.label' <<<"$ACCOUNT_JSON")"
  ACCOUNT_SLUG="$(slugify "$ACCOUNT_LABEL")"
  ACCOUNT_DIR="$RUN_ROOT/$ACCOUNT_SLUG"
  SUMMARY_PATH="$ACCOUNT_DIR/summary.md"
  EVIDENCE_PATH="$ACCOUNT_DIR/evidence.json"
  STATUS_PATH="$ACCOUNT_DIR/status.json"
  LAST_MESSAGE_PATH="$ACCOUNT_DIR/last_message.md"
  EVENTS_PATH="$ACCOUNT_DIR/events.jsonl"
  STDERR_PATH="$ACCOUNT_DIR/exec.stderr.log"

  mkdir -p "$ACCOUNT_DIR"
  printf '%s\n' "$ACCOUNT_JSON" > "$ACCOUNT_DIR/account.json"

  RUN_METADATA="$(jq -n \
    --arg run_id "$RUN_ID" \
    --arg generated_at "$GENERATED_AT" \
    --arg repo_root "$REPO_ROOT" \
    --arg workflow_root "$WORKFLOW_ROOT" \
    --arg account_dir "$ACCOUNT_DIR" \
    --arg summary_path "$SUMMARY_PATH" \
    --arg evidence_path "$EVIDENCE_PATH" \
    --arg status_path "$STATUS_PATH" \
    --arg last_message_path "$LAST_MESSAGE_PATH" \
    --arg events_path "$EVENTS_PATH" \
    --arg stderr_path "$STDERR_PATH" \
    --arg config_path "$CONFIG_PATH" \
    --arg workspace_label "$(jq -r '.workspace_label // "unova-drive-notion-sweep"' "$CONFIG_PATH")" \
    --arg notes "$(jq -r '.notes // ""' "$CONFIG_PATH")" \
    --argjson account "$ACCOUNT_JSON" \
    '{
      run_id: $run_id,
      generated_at: $generated_at,
      workspace_label: $workspace_label,
      notes: $notes,
      config_path: $config_path,
      repo_root: $repo_root,
      workflow_root: $workflow_root,
      account_dir: $account_dir,
      summary_path: $summary_path,
      evidence_path: $evidence_path,
      status_path: $status_path,
      last_message_path: $last_message_path,
      events_path: $events_path,
      stderr_path: $stderr_path,
      account: $account
    }')"

  printf '%s\n' "$RUN_METADATA" > "$ACCOUNT_DIR/run-metadata.json"

  {
    cat "$PROMPT_TEMPLATE"
    printf '\n\n## Run Metadata JSON\n```json\n%s\n```\n' "$RUN_METADATA"
  } > "$ACCOUNT_DIR/prompt.md"

  if (( DRY_RUN )); then
    printf 'Dry run only for %s.\n' "$ACCOUNT_LABEL" > "$SUMMARY_PATH"
    write_fallback_status \
      "$STATUS_PATH" \
      "$EVIDENCE_PATH" \
      "$RUN_ID" \
      "$ACCOUNT_LABEL" \
      "dry_run" \
      "Dry run only. Prompt and metadata were generated; Codex was not executed." \
      "$SUMMARY_PATH" \
      '[]'
    STATUS_FILES+=("$STATUS_PATH")
    continue
  fi

  if codex exec --full-auto --cd "$REPO_ROOT" --json --output-last-message "$LAST_MESSAGE_PATH" \
      < "$ACCOUNT_DIR/prompt.md" > "$EVENTS_PATH" 2> "$STDERR_PATH"; then
    :
  else
    printf 'Sweep execution failed for %s.\n' "$ACCOUNT_LABEL" > "$SUMMARY_PATH"
    ERROR_JSON="$(
      if [[ -s "$STDERR_PATH" ]]; then
        jq -Rs 'split("\n") | map(select(length > 0))' < "$STDERR_PATH"
      else
        printf '%s' '["codex exec failed before status.json could be written"]'
      fi
    )"
    write_fallback_status \
      "$STATUS_PATH" \
      "$EVIDENCE_PATH" \
      "$RUN_ID" \
      "$ACCOUNT_LABEL" \
      "failed" \
      "codex exec returned a non-zero exit status before producing sweep artifacts. See exec.stderr.log." \
      "$SUMMARY_PATH" \
      "$ERROR_JSON"
    STATUS_FILES+=("$STATUS_PATH")
    continue
  fi

  if [[ ! -f "$STATUS_PATH" ]]; then
    printf 'No status.json was written for %s.\n' "$ACCOUNT_LABEL" > "$SUMMARY_PATH"
    write_fallback_status \
      "$STATUS_PATH" \
      "$EVIDENCE_PATH" \
      "$RUN_ID" \
      "$ACCOUNT_LABEL" \
      "failed" \
      "The sweep completed without writing status.json." \
      "$SUMMARY_PATH" \
      '["status.json was not created by the agent"]'
  fi

  if ! jq -e . "$STATUS_PATH" >/dev/null 2>&1; then
    printf 'status.json was invalid for %s.\n' "$ACCOUNT_LABEL" > "$SUMMARY_PATH"
    write_fallback_status \
      "$STATUS_PATH" \
      "$EVIDENCE_PATH" \
      "$RUN_ID" \
      "$ACCOUNT_LABEL" \
      "failed" \
      "The sweep wrote an unreadable status.json file." \
      "$SUMMARY_PATH" \
      '["status.json exists but is not valid JSON"]'
  fi

  if [[ ! -f "$EVIDENCE_PATH" ]] || ! jq -e . "$EVIDENCE_PATH" >/dev/null 2>&1; then
    jq -n \
      --arg run_id "$RUN_ID" \
      --arg account_label "$ACCOUNT_LABEL" \
      '{
        run_id: $run_id,
        account_label: $account_label,
        observed_identities: {
          google_drive: {
            name: null,
            email: null
          },
          notion: {
            name: null,
            email: null
          }
        },
        evidence: []
      }' > "$EVIDENCE_PATH"
  fi

  STATUS_FILES+=("$STATUS_PATH")
done < <(
  if [[ -n "$ACCOUNT_FILTER" ]]; then
    jq -c --arg label "$ACCOUNT_FILTER" "$ACCOUNT_QUERY" "$CONFIG_PATH"
  else
    jq -c "$ACCOUNT_QUERY" "$CONFIG_PATH"
  fi
)

jq -s \
  --arg run_id "$RUN_ID" \
  --arg generated_at "$GENERATED_AT" \
  --arg config_path "$CONFIG_PATH" \
  --arg run_root "$RUN_ROOT" \
  '{
    run_id: $run_id,
    generated_at: $generated_at,
    config_path: $config_path,
    run_root: $run_root,
    counts: {
      total: length,
      completed: map(select(.status == "completed")) | length,
      partial: map(select(.status == "partial")) | length,
      mismatched: map(select(.status == "account_mismatch")) | length,
      failed: map(select(.status == "failed")) | length,
      dry_run: map(select(.status == "dry_run")) | length
    },
    accounts: .
  }' "${STATUS_FILES[@]}" > "$RUN_ROOT/manifest.json"

printf 'Run complete: %s\n' "$RUN_ROOT"
printf 'Manifest: %s\n' "$RUN_ROOT/manifest.json"
