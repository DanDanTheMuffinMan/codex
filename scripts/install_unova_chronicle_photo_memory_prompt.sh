#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_SOURCE="$REPO_ROOT/unova/chronicle-photo-memory/interactive-prompt.md"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
PROMPTS_DIR="$CODEX_HOME_DIR/prompts"
PROMPT_TARGET="$PROMPTS_DIR/unova-chronicle-photo-memory.md"

mkdir -p "$PROMPTS_DIR"
ln -sfn "$PROMPT_SOURCE" "$PROMPT_TARGET"

printf 'Installed prompt: %s -> %s\n' "$PROMPT_TARGET" "$PROMPT_SOURCE"
printf 'Restart Codex or open a new session, then run:\n'
printf '/prompts:unova-chronicle-photo-memory CONFIG=/absolute/path/to/config.json\n'
