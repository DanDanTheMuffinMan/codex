# UNOVA Home Sale Inventory Desk

This workflow turns a pile of home-sale photos into a repeatable resale desk:

- stage photos into clean upload batches
- create a manifest and upload order for each batch
- use a ChatGPT Project or Codex prompt to identify items
- rank valuable items, quick-sell items, bundles, donations, and research needs
- produce listing titles, price bands, venue recommendations, and post copy
- keep local artifacts so every pass can be rerun or audited

## What it creates

Each staged batch lands under `unova/home-sale-inventory-desk/runs/<timestamp>-<label>/`.

The staging script writes:

- `photos/`: copied or linked images with stable batch filenames
- `photo-manifest.json`: machine-readable photo manifest
- `photo-manifest.csv`: spreadsheet-friendly photo manifest
- `upload-order.txt`: exact file order to upload
- `batch-prompt.md`: prompt to paste with the uploaded photos
- `review-gallery.html`: local thumbnail review cockpit with note/export controls
- `run-metadata.json`: paths, batch label, room, notes, and settings
- `inventory-template.csv`, `research-queue-template.csv`, `listing-drafts-template.md`, `status-template.json`: blank output scaffolds

The analysis prompt expects the assistant to write or return:

- `inventory.csv`: master item table
- `summary.md`: human-readable batch summary
- `research-queue.csv`: high-value / uncertain items that need comps
- `listing-drafts.md`: marketplace-ready listing drafts
- `status.json`: machine-readable run outcome

## Fast path

Install the reusable Codex prompt:

```bash
./scripts/install_unova_home_sale_inventory_prompt.sh
```

Stage one room or category:

```bash
./scripts/stage_home_sale_photo_batch.sh \
  --source "/absolute/path/to/photos/Garage" \
  --batch-label garage-001 \
  --room Garage \
  --notes "Friend selling home; prioritize tools, equipment, and quick local sales."
```

If you want a safe local drop zone, put photos here:

```text
unova/home-sale-inventory-desk/incoming/
```

Then stage from:

```bash
./scripts/stage_home_sale_photo_batch.sh \
  --source unova/home-sale-inventory-desk/incoming \
  --batch-label first-pass-001 \
  --room "Mixed first pass" \
  --notes "Initial friend demo batch."
```

Then upload the staged `photos/` folder to a ChatGPT Project using the instructions in:

```text
unova/home-sale-inventory-desk/chatgpt-project-instructions.md
```

Paste the generated:

```text
unova/home-sale-inventory-desk/runs/latest/batch-prompt.md
```

Optional preflight:

```bash
open unova/home-sale-inventory-desk/runs/latest/review-gallery.html
```

Use the gallery to mark private/sensitive images, note missing close-ups, copy the batch prompt, and export review notes before uploading.

To reopen the latest desk later:

```bash
./scripts/open_home_sale_inventory_desk.sh
```

## ChatGPT Project path

Create a ChatGPT Project named:

```text
Home Sale Inventory Desk
```

Paste [`chatgpt-project-instructions.md`](./chatgpt-project-instructions.md) into the Project instructions.

Use batches of 10 to 40 photos. Prefer one room or one category per batch. For each batch, upload the staged images and paste that batch's generated `batch-prompt.md`.

## Codex prompt path

After installing the prompt, run:

```text
/prompts:unova-home-sale-inventory CONFIG=/absolute/path/to/home-sale-inventory.json
```

Optional overrides:

```text
/prompts:unova-home-sale-inventory CONFIG=/absolute/path/to/home-sale-inventory.json BATCH_RUN=/absolute/path/to/staged/run
```

The Codex prompt is designed for the current desktop session. It can guide or operate the browser lane, but personal photo uploads should stay explicit and visible.

## Pricing posture

The system uses price bands instead of fake precision:

- quick sell price
- fair market price
- high ask price
- acceptable minimum

Use sold/completed comps where possible. For bulky local pickup items, local marketplace prices matter more than national asking prices.

## Venue rules

- Facebook Marketplace / OfferUp: bulky local furniture, decor, outdoor gear, appliances
- Craigslist: tools, garage, furniture, appliances
- eBay: shippable branded items, electronics, collectibles
- Reverb: instruments and serious audio gear
- Chairish / 1stDibs: designer furniture, art, higher-end decor
- Mercari / Poshmark: small household items, apparel, accessories
- Habitat ReStore / donation / free pickup: low-value bulky items

## Safety notes

- Do not upload photos that reveal private documents, addresses, financial records, medical info, minors, or sensitive personal material unless those details are cropped or excluded.
- If sensitive content appears, skip it and record a skip reason.
- Never invent brand, model, age, authenticity, or market value when the photo does not support it.
- Keep exact pickup address out of listing drafts until a buyer is vetted.
