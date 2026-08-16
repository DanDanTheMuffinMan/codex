#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/unova-workflow-validate.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

log() {
  printf '%s\n' "$1"
}

relative_path() {
  local path="$1"
  if [[ "$path" == "$REPO_ROOT/"* ]]; then
    printf '%s' "${path#"$REPO_ROOT"/}"
  else
    printf '%s' "$path"
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
}

check_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf 'Missing required file: %s\n' "$path" >&2
    exit 1
  fi
}

check_json() {
  local path="$1"
  jq -e . "$path" >/dev/null
  log "PASS json: $(relative_path "$path")"
}

check_script_syntax() {
  local path="$1"
  bash -n "$path"
  log "PASS bash -n: $(relative_path "$path")"
}

resolve_link_target() {
  local link_path="$1"
  local target
  target="$(readlink "$link_path")"

  if [[ "$target" == /* ]]; then
    printf '%s' "$target"
    return
  fi

  printf '%s' "$(cd "$(dirname "$link_path")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")"
}

validate_prompt_install() {
  local script_name="$1"
  local prompt_name="$2"
  local source_rel="$3"
  local source_abs="$REPO_ROOT/$source_rel"
  local codex_home="$TMP_ROOT/$prompt_name"
  local prompt_path="$codex_home/prompts/$prompt_name"

  CODEX_HOME="$codex_home" "$REPO_ROOT/scripts/$script_name" >/dev/null

  if [[ ! -L "$prompt_path" ]]; then
    printf 'Expected symlink not created: %s\n' "$prompt_path" >&2
    exit 1
  fi

  local target
  target="$(resolve_link_target "$prompt_path")"
  if [[ "$target" != "$source_abs" ]]; then
    printf 'Unexpected symlink target for %s: %s (expected %s)\n' "$prompt_path" "$target" "$source_abs" >&2
    exit 1
  fi

  log "PASS prompt install: scripts/$script_name"
}

require_cmd jq
require_cmd readlink

SCRIPT_PATHS=(
  "$REPO_ROOT/scripts/install_unova_chronicle_photo_memory_prompt.sh"
  "$REPO_ROOT/scripts/install_unova_drive_notion_sweep_prompt.sh"
  "$REPO_ROOT/scripts/install_unova_home_sale_inventory_prompt.sh"
  "$REPO_ROOT/scripts/install_unova_relay_urgency_escalator_prompt.sh"
  "$REPO_ROOT/scripts/run_unova_drive_notion_sweep.sh"
  "$REPO_ROOT/scripts/stage_home_sale_photo_batch.sh"
  "$REPO_ROOT/scripts/open_home_sale_inventory_desk.sh"
)

for script_path in "${SCRIPT_PATHS[@]}"; do
  check_file "$script_path"
  check_script_syntax "$script_path"
done

JSON_CONFIGS=(
  "$REPO_ROOT/unova/chronicle-photo-memory/config.example.json"
  "$REPO_ROOT/unova/google-drive-notion-sweep/config.example.json"
  "$REPO_ROOT/unova/home-sale-inventory-desk/config.example.json"
  "$REPO_ROOT/unova/relay-urgency-escalator/config.example.json"
)

for config_path in "${JSON_CONFIGS[@]}"; do
  check_file "$config_path"
  check_json "$config_path"
done

REQUIRED_DOCS=(
  "$REPO_ROOT/unova/chronicle-photo-memory/README.md"
  "$REPO_ROOT/unova/chronicle-photo-memory/prompt.md"
  "$REPO_ROOT/unova/chronicle-photo-memory/interactive-prompt.md"
  "$REPO_ROOT/unova/google-drive-notion-sweep/README.md"
  "$REPO_ROOT/unova/google-drive-notion-sweep/prompt.md"
  "$REPO_ROOT/unova/google-drive-notion-sweep/interactive-prompt.md"
  "$REPO_ROOT/unova/home-sale-inventory-desk/README.md"
  "$REPO_ROOT/unova/home-sale-inventory-desk/prompt.md"
  "$REPO_ROOT/unova/home-sale-inventory-desk/interactive-prompt.md"
  "$REPO_ROOT/unova/relay-urgency-escalator/README.md"
  "$REPO_ROOT/unova/relay-urgency-escalator/prompt.md"
  "$REPO_ROOT/unova/relay-urgency-escalator/interactive-prompt.md"
  "$REPO_ROOT/unova/live-sense-bridge/README.md"
)

for doc_path in "${REQUIRED_DOCS[@]}"; do
  check_file "$doc_path"
done
log "PASS docs: required UNOVA workflow docs present"

validate_prompt_install \
  "install_unova_chronicle_photo_memory_prompt.sh" \
  "unova-chronicle-photo-memory.md" \
  "unova/chronicle-photo-memory/interactive-prompt.md"
validate_prompt_install \
  "install_unova_drive_notion_sweep_prompt.sh" \
  "unova-drive-notion-sweep.md" \
  "unova/google-drive-notion-sweep/interactive-prompt.md"
validate_prompt_install \
  "install_unova_home_sale_inventory_prompt.sh" \
  "unova-home-sale-inventory.md" \
  "unova/home-sale-inventory-desk/interactive-prompt.md"
validate_prompt_install \
  "install_unova_relay_urgency_escalator_prompt.sh" \
  "unova-relay-urgency-escalator.md" \
  "unova/relay-urgency-escalator/interactive-prompt.md"

"$REPO_ROOT/scripts/run_unova_drive_notion_sweep.sh" --help >/dev/null
log "PASS help: scripts/run_unova_drive_notion_sweep.sh --help"

"$REPO_ROOT/scripts/stage_home_sale_photo_batch.sh" --help >/dev/null
log "PASS help: scripts/stage_home_sale_photo_batch.sh --help"

if command -v codex >/dev/null 2>&1; then
  DRY_RUN_OUTPUT="$TMP_ROOT/drive-sweep"
  "$REPO_ROOT/scripts/run_unova_drive_notion_sweep.sh" \
    --config "$REPO_ROOT/unova/google-drive-notion-sweep/config.example.json" \
    --output-root "$DRY_RUN_OUTPUT" \
    --dry-run >/dev/null

  MANIFEST_PATH="$DRY_RUN_OUTPUT/latest/manifest.json"
  check_file "$MANIFEST_PATH"
  jq -e '.counts.total >= 1 and .counts.dry_run == .counts.total and .counts.failed == 0' "$MANIFEST_PATH" >/dev/null || {
    printf 'FAIL dry-run manifest check: unexpected counts in %s\n' "$MANIFEST_PATH" >&2
    exit 1
  }
  log "PASS dry-run: scripts/run_unova_drive_notion_sweep.sh"
else
  log "SKIP dry-run: codex command not available"
fi

log "UNOVA workflow validation passed."
