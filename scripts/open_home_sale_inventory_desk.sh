#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_ROOT="$REPO_ROOT/unova/home-sale-inventory-desk"
LATEST_RUN="$WORKFLOW_ROOT/runs/latest"

printf 'Home Sale Inventory Desk\n'
printf 'Workflow: %s\n' "$WORKFLOW_ROOT"
printf 'Project instructions: %s\n' "$WORKFLOW_ROOT/chatgpt-project-instructions.md"
printf 'Friend brief: %s\n' "$WORKFLOW_ROOT/friend-demo-brief.md"

if [[ -e "$LATEST_RUN/review-gallery.html" ]]; then
  printf 'Opening latest review gallery: %s\n' "$LATEST_RUN/review-gallery.html"
  open "$LATEST_RUN/review-gallery.html"
else
  printf 'No staged batch yet. Create one with:\n'
  printf './scripts/stage_home_sale_photo_batch.sh --source "/absolute/path/to/photos" --batch-label garage-001 --room Garage\n'
fi

if [[ "${1:-}" == "--chatgpt" ]]; then
  open "https://chatgpt.com/"
fi

