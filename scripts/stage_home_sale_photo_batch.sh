#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: stage_home_sale_photo_batch.sh --source PATH --batch-label LABEL [options]

Stages a home-sale photo batch for ChatGPT/Codex analysis.

Options:
  -s, --source PATH        Source folder containing photos.
  -b, --batch-label LABEL  Stable batch label, e.g. garage-001.
  -r, --room NAME          Room/category label.
  -n, --notes TEXT         Seller or batch notes.
  -o, --output-root PATH   Output root for run artifacts.
      --max-files N        Maximum photos to stage. Default: all.
      --mode MODE          copy or link. Default: copy.
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
    raw="batch"
  fi
  printf '%s' "$raw"
}

lower_ext() {
  local file="$1"
  local base="${file##*/}"
  local ext="${base##*.}"
  if [[ "$base" == "$ext" ]]; then
    printf 'jpg'
    return
  fi
  printf '%s' "$ext" | tr '[:upper:]' '[:lower:]'
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_ROOT="$REPO_ROOT/unova/home-sale-inventory-desk"

SOURCE_PATH=""
BATCH_LABEL=""
ROOM=""
NOTES=""
OUTPUT_ROOT="$WORKFLOW_ROOT/runs"
MAX_FILES=""
MODE="copy"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--source)
      [[ $# -ge 2 ]] || fail "--source requires a value"
      SOURCE_PATH="$2"
      shift 2
      ;;
    -b|--batch-label)
      [[ $# -ge 2 ]] || fail "--batch-label requires a value"
      BATCH_LABEL="$2"
      shift 2
      ;;
    -r|--room)
      [[ $# -ge 2 ]] || fail "--room requires a value"
      ROOM="$2"
      shift 2
      ;;
    -n|--notes)
      [[ $# -ge 2 ]] || fail "--notes requires a value"
      NOTES="$2"
      shift 2
      ;;
    -o|--output-root)
      [[ $# -ge 2 ]] || fail "--output-root requires a value"
      OUTPUT_ROOT="$2"
      shift 2
      ;;
    --max-files)
      [[ $# -ge 2 ]] || fail "--max-files requires a value"
      MAX_FILES="$2"
      shift 2
      ;;
    --mode)
      [[ $# -ge 2 ]] || fail "--mode requires a value"
      MODE="$2"
      shift 2
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

[[ -n "$SOURCE_PATH" ]] || fail "--source is required"
[[ -n "$BATCH_LABEL" ]] || fail "--batch-label is required"
[[ "$MODE" == "copy" || "$MODE" == "link" ]] || fail "--mode must be copy or link"

if [[ "$SOURCE_PATH" != /* ]]; then
  SOURCE_PATH="$REPO_ROOT/$SOURCE_PATH"
fi

if [[ "$OUTPUT_ROOT" != /* ]]; then
  OUTPUT_ROOT="$REPO_ROOT/$OUTPUT_ROOT"
fi

[[ -d "$SOURCE_PATH" ]] || fail "source folder not found: $SOURCE_PATH"

if [[ -n "$MAX_FILES" && ! "$MAX_FILES" =~ ^[0-9]+$ ]]; then
  fail "--max-files must be a positive integer"
fi

require_cmd jq
require_cmd shasum

BATCH_SLUG="$(slugify "$BATCH_LABEL")"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$BATCH_SLUG"
GENERATED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
RUN_ROOT="$OUTPUT_ROOT/$RUN_ID"
PHOTOS_DIR="$RUN_ROOT/photos"
PHOTO_JSONL="$RUN_ROOT/photo-manifest.jsonl"
PHOTO_MANIFEST_JSON="$RUN_ROOT/photo-manifest.json"
PHOTO_MANIFEST_CSV="$RUN_ROOT/photo-manifest.csv"
UPLOAD_ORDER="$RUN_ROOT/upload-order.txt"
BATCH_PROMPT="$RUN_ROOT/batch-prompt.md"
RUN_METADATA="$RUN_ROOT/run-metadata.json"
REVIEW_GALLERY="$RUN_ROOT/review-gallery.html"
INVENTORY_TEMPLATE="$RUN_ROOT/inventory-template.csv"
RESEARCH_QUEUE_TEMPLATE="$RUN_ROOT/research-queue-template.csv"
LISTING_DRAFTS_TEMPLATE="$RUN_ROOT/listing-drafts-template.md"
STATUS_TEMPLATE="$RUN_ROOT/status-template.json"

mkdir -p "$PHOTOS_DIR"
: > "$PHOTO_JSONL"
: > "$UPLOAD_ORDER"

COUNT=0

while IFS= read -r PHOTO_PATH; do
  if [[ -n "$MAX_FILES" && "$COUNT" -ge "$MAX_FILES" ]]; then
    break
  fi

  COUNT=$((COUNT + 1))
  EXT="$(lower_ext "$PHOTO_PATH")"
  PHOTO_ID="$(printf '%s-P%03d' "$BATCH_SLUG" "$COUNT")"
  STAGED_NAME="$(printf '%s.%s' "$PHOTO_ID" "$EXT")"
  STAGED_PATH="$PHOTOS_DIR/$STAGED_NAME"

  if [[ "$MODE" == "link" ]]; then
    ln -f "$PHOTO_PATH" "$STAGED_PATH" 2>/dev/null || cp -p "$PHOTO_PATH" "$STAGED_PATH"
  else
    cp -p "$PHOTO_PATH" "$STAGED_PATH"
  fi

  SHA256="$(shasum -a 256 "$PHOTO_PATH" | awk '{print $1}')"
  BYTES="$(stat -f '%z' "$PHOTO_PATH")"
  ORIGINAL_NAME="$(basename "$PHOTO_PATH")"

  printf '%s\n' "$STAGED_PATH" >> "$UPLOAD_ORDER"

  jq -n \
    --arg photo_id "$PHOTO_ID" \
    --arg batch_label "$BATCH_LABEL" \
    --arg room "$ROOM" \
    --arg original_name "$ORIGINAL_NAME" \
    --arg original_path "$PHOTO_PATH" \
    --arg staged_name "$STAGED_NAME" \
    --arg staged_path "$STAGED_PATH" \
    --arg sha256 "$SHA256" \
    --argjson bytes "$BYTES" \
    '{
      photo_id: $photo_id,
      batch_label: $batch_label,
      room: $room,
      original_name: $original_name,
      original_path: $original_path,
      staged_name: $staged_name,
      staged_path: $staged_path,
      sha256: $sha256,
      bytes: $bytes
    }' >> "$PHOTO_JSONL"
done < <(
  find "$SOURCE_PATH" -type f \( \
    -iname '*.jpg' -o \
    -iname '*.jpeg' -o \
    -iname '*.png' -o \
    -iname '*.heic' -o \
    -iname '*.webp' -o \
    -iname '*.tif' -o \
    -iname '*.tiff' \
  \) | LC_ALL=C sort
)

if [[ "$COUNT" -eq 0 ]]; then
  fail "no supported image files found in $SOURCE_PATH"
fi

jq -s \
  --arg run_id "$RUN_ID" \
  --arg generated_at "$GENERATED_AT" \
  --arg source_path "$SOURCE_PATH" \
  --arg photos_dir "$PHOTOS_DIR" \
  --arg batch_label "$BATCH_LABEL" \
  --arg room "$ROOM" \
  --arg notes "$NOTES" \
  '{
    run_id: $run_id,
    generated_at: $generated_at,
    source_path: $source_path,
    photos_dir: $photos_dir,
    batch_label: $batch_label,
    room: $room,
    notes: $notes,
    photo_count: length,
    photos: .
  }' "$PHOTO_JSONL" > "$PHOTO_MANIFEST_JSON"

jq -r '
  ["photo_id","batch_label","room","original_name","original_path","staged_name","staged_path","sha256","bytes"],
  (.photos[] | [.photo_id,.batch_label,.room,.original_name,.original_path,.staged_name,.staged_path,.sha256,.bytes])
  | @csv
' "$PHOTO_MANIFEST_JSON" > "$PHOTO_MANIFEST_CSV"

jq -n \
  --arg run_id "$RUN_ID" \
  --arg generated_at "$GENERATED_AT" \
  --arg repo_root "$REPO_ROOT" \
  --arg workflow_root "$WORKFLOW_ROOT" \
  --arg run_root "$RUN_ROOT" \
  --arg photos_dir "$PHOTOS_DIR" \
  --arg photo_manifest_json "$PHOTO_MANIFEST_JSON" \
  --arg photo_manifest_csv "$PHOTO_MANIFEST_CSV" \
  --arg upload_order "$UPLOAD_ORDER" \
  --arg batch_prompt "$BATCH_PROMPT" \
  --arg review_gallery "$REVIEW_GALLERY" \
  --arg batch_label "$BATCH_LABEL" \
  --arg room "$ROOM" \
  --arg notes "$NOTES" \
  --arg mode "$MODE" \
  --argjson photo_count "$COUNT" \
  '{
    run_id: $run_id,
    generated_at: $generated_at,
    repo_root: $repo_root,
    workflow_root: $workflow_root,
    run_root: $run_root,
    photos_dir: $photos_dir,
    photo_manifest_json: $photo_manifest_json,
    photo_manifest_csv: $photo_manifest_csv,
    upload_order: $upload_order,
    batch_prompt: $batch_prompt,
    review_gallery: $review_gallery,
    batch_label: $batch_label,
    room: $room,
    notes: $notes,
    mode: $mode,
    photo_count: $photo_count
  }' > "$RUN_METADATA"

cat > "$BATCH_PROMPT" <<EOF
Batch: $BATCH_LABEL
Room/Category: ${ROOM:-Unspecified}
Market: use the configured seller market unless I say otherwise.
Notes: ${NOTES:-None}

Analyze the uploaded photos in this staged order:

\`\`\`text
$(sed 's|.*/||' "$UPLOAD_ORDER")
\`\`\`

Return:

1. Inventory table using the Home Sale Inventory Desk columns.
2. Top valuable items.
3. Fastest-sale items.
4. Items needing closer photos, labels, measurements, or model numbers.
5. Bundle, donate, free pickup, recycle, or dispose recommendations.
6. First-pass listing titles and prices.
7. Research queue.

Use price bands:

- Quick Sell Price
- Fair Market Price
- High Ask Price
- Acceptable Minimum

Mark confidence honestly. Do not invent brand/model/value when the image does not prove it.
EOF

printf '%s\n' \
  'Item ID,Batch,Photo/File,Room,Item,Brand/Model,Category,Condition,Priority,Quick Sell Price,Fair Market Price,High Ask Price,Acceptable Minimum,Best Venue,Research Needed,Confidence,Listing Title,Listing Description,Missing Info,Status' \
  > "$INVENTORY_TEMPLATE"

printf '%s\n' \
  'Item ID,Reason,Needed Evidence,Research Target,Best Venue,Estimated Upside,Confidence' \
  > "$RESEARCH_QUEUE_TEMPLATE"

cat > "$LISTING_DRAFTS_TEMPLATE" <<EOF
# Listing Drafts: $BATCH_LABEL

Use one section per item.

## ITEM-ID

- Platform:
- Title:
- List price:
- Acceptable minimum:
- Description:
- Condition notes:
- Pickup/shipping note:
- Keywords:
- Questions before posting:
EOF

jq -n \
  --arg batch_label "$BATCH_LABEL" \
  --arg status "needs_analysis" \
  --arg summary "Photos staged; analysis has not been run yet." \
  --arg inventory_csv "$RUN_ROOT/inventory.csv" \
  --arg summary_md "$RUN_ROOT/summary.md" \
  --arg research_queue_csv "$RUN_ROOT/research-queue.csv" \
  --arg listing_drafts_md "$RUN_ROOT/listing-drafts.md" \
  --arg status_json "$RUN_ROOT/status.json" \
  --argjson photo_count "$COUNT" \
  '{
    batch_label: $batch_label,
    status: $status,
    summary: $summary,
    counts: {
      photos: $photo_count,
      items: 0,
      priority_a: 0,
      priority_b: 0,
      priority_c: 0,
      priority_d: 0,
      research_needed: 0
    },
    artifact_paths: {
      inventory_csv: $inventory_csv,
      summary_md: $summary_md,
      research_queue_csv: $research_queue_csv,
      listing_drafts_md: $listing_drafts_md,
      status_json: $status_json
    },
    errors: []
  }' > "$STATUS_TEMPLATE"

GALLERY_DATA="$(jq -c '.photos' "$PHOTO_MANIFEST_JSON")"
BATCH_PROMPT_JSON="$(jq -Rs . < "$BATCH_PROMPT")"

cat > "$REVIEW_GALLERY" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Home Sale Inventory Desk - $BATCH_LABEL</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #19201d;
      --muted: #65716b;
      --line: #d8ded9;
      --paper: #f8faf7;
      --panel: #ffffff;
      --accent: #1d6d5f;
      --warm: #af5f35;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--paper);
      color: var(--ink);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 15px;
    }
    header {
      position: sticky;
      top: 0;
      z-index: 2;
      border-bottom: 1px solid var(--line);
      background: rgba(248, 250, 247, 0.96);
      backdrop-filter: blur(12px);
    }
    .bar {
      display: flex;
      gap: 16px;
      align-items: center;
      justify-content: space-between;
      padding: 14px 18px;
    }
    h1 {
      margin: 0;
      font-size: 18px;
      letter-spacing: 0;
    }
    h2 {
      font-size: 17px;
      letter-spacing: 0;
    }
    .meta {
      color: var(--muted);
      font-size: 13px;
      margin-top: 3px;
    }
    .actions {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    button {
      border: 1px solid var(--line);
      background: var(--panel);
      color: var(--ink);
      border-radius: 6px;
      padding: 8px 10px;
      font: inherit;
      cursor: pointer;
    }
    button.primary {
      background: var(--accent);
      border-color: var(--accent);
      color: white;
    }
    main { padding: 18px; }
    .notice {
      border-left: 4px solid var(--warm);
      background: #fff7ef;
      padding: 12px;
      margin-bottom: 16px;
      color: #4e3427;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
      gap: 14px;
    }
    article {
      border: 1px solid var(--line);
      background: var(--panel);
      border-radius: 8px;
      overflow: hidden;
    }
    img {
      display: block;
      width: 100%;
      aspect-ratio: 4 / 3;
      object-fit: cover;
      background: #e6ebe7;
    }
    .body { padding: 12px; }
    .photo-id {
      font-weight: 700;
      margin-bottom: 4px;
    }
    .file {
      color: var(--muted);
      font-size: 12px;
      overflow-wrap: anywhere;
    }
    label {
      display: block;
      margin-top: 10px;
      color: var(--muted);
      font-size: 12px;
    }
    textarea, select {
      width: 100%;
      margin-top: 4px;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 8px;
      font: inherit;
      background: white;
      color: var(--ink);
    }
    textarea {
      min-height: 68px;
      resize: vertical;
    }
    .checks {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
      margin-top: 10px;
    }
    .checks label {
      display: flex;
      align-items: center;
      gap: 6px;
      margin: 0;
      color: var(--ink);
      font-size: 13px;
    }
    pre {
      white-space: pre-wrap;
      border: 1px solid var(--line);
      background: var(--panel);
      border-radius: 8px;
      padding: 12px;
      overflow: auto;
    }
    @media (max-width: 720px) {
      .bar {
        align-items: flex-start;
        flex-direction: column;
      }
      .actions { justify-content: flex-start; }
    }
  </style>
</head>
<body>
  <header>
    <div class="bar">
      <div>
        <h1>Home Sale Inventory Desk: $BATCH_LABEL</h1>
        <div class="meta">${ROOM:-Unspecified room} - $COUNT photos - ${NOTES:-No notes}</div>
      </div>
      <div class="actions">
        <button class="primary" id="copyPrompt">Copy Batch Prompt</button>
        <button id="downloadNotes">Download Notes CSV</button>
        <button id="showPrompt">Show Prompt</button>
      </div>
    </div>
  </header>
  <main>
    <div class="notice">
      Review photos before upload. Mark private/sensitive images for exclusion, add close-up needs, then upload the clean batch to ChatGPT with the copied prompt.
    </div>
    <section class="grid" id="gallery"></section>
    <section id="promptPanel" hidden>
      <h2>Batch Prompt</h2>
      <pre id="promptText"></pre>
    </section>
  </main>
  <script>
    const photos = $GALLERY_DATA;
    const batchPrompt = $BATCH_PROMPT_JSON;
    const storageKey = "home-sale-inventory:$RUN_ID";
    const saved = JSON.parse(localStorage.getItem(storageKey) || "{}");
    const gallery = document.getElementById("gallery");
    const promptText = document.getElementById("promptText");
    promptText.textContent = batchPrompt;

    function fieldSelector(field, photoId) {
      return '[data-field="' + field + '"][data-id="' + photoId + '"]';
    }

    function save() {
      const data = {};
      for (const photo of photos) {
        data[photo.photo_id] = {
          status: document.querySelector(fieldSelector("status", photo.photo_id)).value,
          notes: document.querySelector(fieldSelector("notes", photo.photo_id)).value,
          private: document.querySelector(fieldSelector("private", photo.photo_id)).checked,
          closeup: document.querySelector(fieldSelector("closeup", photo.photo_id)).checked
        };
      }
      localStorage.setItem(storageKey, JSON.stringify(data));
    }

    function csvCell(value) {
      return '"' + String(value || "").replaceAll('"', '""') + '"';
    }

    function download(filename, text) {
      const blob = new Blob([text], { type: "text/csv;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = filename;
      link.click();
      URL.revokeObjectURL(url);
    }

    function render() {
      gallery.innerHTML = "";
      for (const photo of photos) {
        const state = saved[photo.photo_id] || {};
        const card = document.createElement("article");
        const image = document.createElement("img");
        image.src = "photos/" + photo.staged_name;
        image.alt = photo.photo_id;

        const body = document.createElement("div");
        body.className = "body";
        body.innerHTML =
          '<div class="photo-id"></div>' +
          '<div class="file"></div>' +
          '<label>Status<select data-field="status" data-id="' + photo.photo_id + '">' +
          '<option value="ready">Ready to upload</option>' +
          '<option value="skip">Skip</option>' +
          '<option value="needs_crop">Needs crop</option>' +
          '<option value="needs_reshoot">Needs reshoot</option>' +
          '</select></label>' +
          '<label>Notes<textarea data-field="notes" data-id="' + photo.photo_id + '" placeholder="Visible item, model label needed, private doc in frame..."></textarea></label>' +
          '<div class="checks">' +
          '<label><input type="checkbox" data-field="private" data-id="' + photo.photo_id + '"> private/sensitive</label>' +
          '<label><input type="checkbox" data-field="closeup" data-id="' + photo.photo_id + '"> needs close-up</label>' +
          '</div>';

        body.querySelector(".photo-id").textContent = photo.photo_id;
        body.querySelector(".file").textContent = photo.original_name;
        card.appendChild(image);
        card.appendChild(body);
        gallery.appendChild(card);

        card.querySelector(fieldSelector("status", photo.photo_id)).value = state.status || "ready";
        card.querySelector(fieldSelector("notes", photo.photo_id)).value = state.notes || "";
        card.querySelector(fieldSelector("private", photo.photo_id)).checked = Boolean(state.private);
        card.querySelector(fieldSelector("closeup", photo.photo_id)).checked = Boolean(state.closeup);
      }
      gallery.addEventListener("input", save);
      gallery.addEventListener("change", save);
    }

    document.getElementById("copyPrompt").addEventListener("click", async () => {
      await navigator.clipboard.writeText(batchPrompt);
      document.getElementById("copyPrompt").textContent = "Copied";
      setTimeout(() => {
        document.getElementById("copyPrompt").textContent = "Copy Batch Prompt";
      }, 1400);
    });

    document.getElementById("downloadNotes").addEventListener("click", () => {
      save();
      const data = JSON.parse(localStorage.getItem(storageKey) || "{}");
      const rows = [["photo_id","staged_name","original_name","status","private_sensitive","needs_closeup","notes"]];
      for (const photo of photos) {
        const state = data[photo.photo_id] || {};
        rows.push([
          photo.photo_id,
          photo.staged_name,
          photo.original_name,
          state.status || "ready",
          state.private ? "yes" : "no",
          state.closeup ? "yes" : "no",
          state.notes || ""
        ]);
      }
      download("$BATCH_SLUG-review-notes.csv", rows.map(row => row.map(csvCell).join(",")).join("\\n") + "\\n");
    });

    document.getElementById("showPrompt").addEventListener("click", () => {
      const panel = document.getElementById("promptPanel");
      panel.hidden = !panel.hidden;
    });

    render();
  </script>
</body>
</html>
EOF

ln -sfn "$RUN_ROOT" "$OUTPUT_ROOT/latest"

printf 'Staged photo batch: %s\n' "$RUN_ROOT"
printf 'Photos: %s\n' "$PHOTOS_DIR"
printf 'Manifest: %s\n' "$PHOTO_MANIFEST_JSON"
printf 'Prompt: %s\n' "$BATCH_PROMPT"
printf 'Review gallery: %s\n' "$REVIEW_GALLERY"
