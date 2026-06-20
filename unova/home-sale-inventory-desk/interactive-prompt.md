---
description: Run the repo's Home Sale Inventory Desk workflow from a config file or staged batch.
argument-hint: CONFIG=<path> [BATCH=<label>] [BATCH_RUN=<path>]
---

Run the Home Sale Inventory Desk workflow from this repo inside the current session.

Inputs:

- `CONFIG`: absolute or repo-relative path to a workflow config JSON file
- `BATCH`: optional batch label; if provided, only process that batch
- `BATCH_RUN`: optional staged run directory from `stage_home_sale_photo_batch.sh`

Instructions:

1. Open `unova/home-sale-inventory-desk/README.md`, `unova/home-sale-inventory-desk/prompt.md`, and the config file at `$CONFIG`.
2. If `BATCH_RUN` is set, open its `run-metadata.json`, `photo-manifest.json`, and `batch-prompt.md`.
3. Use the current session's browser/computer tools only when needed and visible.
4. Do not upload personal photos or submit forms unless the upload target and batch path are explicit in the user's latest instruction or confirmed in this session.
5. For each selected batch, produce or update the required artifacts:
   - `inventory.csv`
   - `summary.md`
   - `research-queue.csv`
   - `listing-drafts.md`
   - `status.json`
6. Keep item claims evidence-based. If brand/model/value is uncertain, mark it uncertain and ask for the exact close-up needed.
7. Prioritize money plus speed: high-value research first, quick local listings second, donation/free lots last.

If the config file has placeholder paths or the staged batch is missing, stop and say exactly what still needs to be filled in.

