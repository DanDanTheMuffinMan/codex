#!/usr/bin/env python3
"""Export recent Photos.app candidates for the Home Sale Inventory Desk.

This script copies safe working derivatives out of the macOS Photos library and
builds contact sheets for fast resale triage. It never writes into the Photos
library.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import shutil
import sqlite3
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


APPLE_EPOCH_OFFSET = 978_307_200
DEFAULT_PHOTOS_LIBRARY = Path.home() / "Pictures/Photos Library.photoslibrary"
DEFAULT_OUTPUT_ROOT = (
    Path("unova") / "home-sale-inventory-desk" / "runs"
)
SUPPORTED_IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".heic", ".tif", ".tiff", ".webp"}


@dataclass(frozen=True)
class Candidate:
    photo_id: str
    uuid: str
    filename: str
    directory: str
    added_local: str
    created_local: str
    import_session: str
    width: int
    height: int
    source_path: str
    staged_name: str
    staged_path: str
    sha256: str
    bytes: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export recent Photos.app resale candidates into a local review run."
    )
    parser.add_argument(
        "--since",
        default="2026-04-16 00:00:00",
        help="Local datetime lower bound for added OR created date.",
    )
    parser.add_argument(
        "--photos-library",
        default=str(DEFAULT_PHOTOS_LIBRARY),
        help="Path to the .photoslibrary bundle.",
    )
    parser.add_argument(
        "--output-root",
        default=str(DEFAULT_OUTPUT_ROOT),
        help="Root folder for generated run artifacts.",
    )
    parser.add_argument(
        "--label",
        default="recent-10-day-resale",
        help="Run label used in output folder and photo IDs.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Optional maximum number of candidates to export.",
    )
    parser.add_argument(
        "--sheet-size",
        type=int,
        default=24,
        help="Number of photos per contact sheet.",
    )
    return parser.parse_args()


def slugify(raw: str) -> str:
    chars: list[str] = []
    last_dash = False
    for char in raw.lower():
        if char.isalnum():
            chars.append(char)
            last_dash = False
        elif not last_dash:
            chars.append("-")
            last_dash = True
    return "".join(chars).strip("-") or "batch"


def connect_photos_db(library: Path) -> sqlite3.Connection:
    db_path = library / "database" / "Photos.sqlite"
    if not db_path.exists():
        raise FileNotFoundError(f"Photos database not found: {db_path}")
    uri = f"file:{db_path}?mode=ro"
    connection = sqlite3.connect(uri, uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def query_assets(connection: sqlite3.Connection, since: str, limit: int) -> list[sqlite3.Row]:
    query = f"""
        SELECT
            ZUUID AS uuid,
            ZFILENAME AS filename,
            ZDIRECTORY AS directory,
            datetime(ZADDEDDATE + {APPLE_EPOCH_OFFSET}, 'unixepoch', 'localtime') AS added_local,
            datetime(ZDATECREATED + {APPLE_EPOCH_OFFSET}, 'unixepoch', 'localtime') AS created_local,
            coalesce(ZIMPORTSESSION, -1) AS import_session,
            coalesce(ZWIDTH, 0) AS width,
            coalesce(ZHEIGHT, 0) AS height
        FROM ZASSET
        WHERE
            (
                datetime(ZADDEDDATE + {APPLE_EPOCH_OFFSET}, 'unixepoch', 'localtime') >= ?
                OR datetime(ZDATECREATED + {APPLE_EPOCH_OFFSET}, 'unixepoch', 'localtime') >= ?
            )
            AND coalesce(ZISDETECTEDSCREENSHOT, 0) = 0
            AND coalesce(ZPLAYBACKSTYLE, 0) <> 4
        ORDER BY
            datetime(ZADDEDDATE + {APPLE_EPOCH_OFFSET}, 'unixepoch', 'localtime') DESC,
            datetime(ZDATECREATED + {APPLE_EPOCH_OFFSET}, 'unixepoch', 'localtime') DESC
    """
    if limit > 0:
        query += " LIMIT ?"
        return list(connection.execute(query, (since, since, limit)))
    return list(connection.execute(query, (since, since)))


def best_source_path(library: Path, row: sqlite3.Row) -> Path | None:
    uuid = row["uuid"]
    directory = row["directory"]
    filename = row["filename"]
    candidates = [
        library / "resources" / "derivatives" / "masters" / directory / f"{uuid}_4_5005_c.jpeg",
        library / "resources" / "derivatives" / directory / f"{uuid}_1_105_c.jpeg",
        library / "resources" / "derivatives" / directory / f"{uuid}_1_102_o.jpeg",
        library / "resources" / "derivatives" / directory / f"{uuid}_1_100_o.jpeg",
        library / "originals" / directory / filename,
    ]
    for path in candidates:
        if path.exists():
            return path
    for root in [library / "resources" / "derivatives", library / "originals"]:
        matches = sorted(root.glob(f"**/{uuid}*"))
        if matches:
            return matches[-1]
    return None


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def export_candidates(rows: list[sqlite3.Row], library: Path, run_root: Path, label: str) -> list[Candidate]:
    photos_dir = run_root / "photos"
    photos_dir.mkdir(parents=True, exist_ok=True)
    slug = slugify(label)
    candidates: list[Candidate] = []
    skipped: list[dict[str, str]] = []

    for index, row in enumerate(rows, start=1):
        source_path = best_source_path(library, row)
        if source_path is None or not source_path.exists():
            skipped.append({"uuid": row["uuid"], "reason": "no readable derivative/original"})
            continue

        suffix = source_path.suffix.lower()
        if suffix not in SUPPORTED_IMAGE_SUFFIXES:
            skipped.append({"uuid": row["uuid"], "reason": f"unsupported suffix {suffix}"})
            continue

        photo_id = f"{slug}-P{index:03d}"
        staged_name = f"{photo_id}{suffix}"
        staged_path = photos_dir / staged_name
        shutil.copy2(source_path, staged_path)
        stat = staged_path.stat()
        candidates.append(
            Candidate(
                photo_id=photo_id,
                uuid=row["uuid"],
                filename=row["filename"],
                directory=row["directory"],
                added_local=row["added_local"],
                created_local=row["created_local"],
                import_session=str(row["import_session"]),
                width=int(row["width"]),
                height=int(row["height"]),
                source_path=str(source_path),
                staged_name=staged_name,
                staged_path=str(staged_path),
                sha256=hash_file(staged_path),
                bytes=stat.st_size,
            )
        )

    if skipped:
        with (run_root / "export-skips.json").open("w", encoding="utf-8") as handle:
            json.dump(skipped, handle, indent=2)
    return candidates


def write_manifests(run_root: Path, candidates: list[Candidate], args: argparse.Namespace) -> None:
    manifest_json = {
        "generated_at": datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
        "label": args.label,
        "since": args.since,
        "photos_library": args.photos_library,
        "photo_count": len(candidates),
        "photos": [asdict(candidate) for candidate in candidates],
    }
    with (run_root / "photo-candidates.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest_json, handle, indent=2)

    fieldnames = list(asdict(candidates[0]).keys()) if candidates else list(Candidate.__dataclass_fields__)
    with (run_root / "photo-candidates.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for candidate in candidates:
            writer.writerow(asdict(candidate))

    with (run_root / "upload-order.txt").open("w", encoding="utf-8") as handle:
        for candidate in candidates:
            handle.write(f"{candidate.staged_path}\n")


def load_font(size: int) -> ImageFont.ImageFont:
    for path in [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNS.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def make_contact_sheets(run_root: Path, candidates: list[Candidate], sheet_size: int) -> list[Path]:
    contact_dir = run_root / "contact-sheets"
    contact_dir.mkdir(parents=True, exist_ok=True)
    sheets: list[Path] = []
    thumb_w, thumb_h = 320, 240
    label_h = 54
    margin = 18
    gap = 14
    cols = 4
    font = load_font(16)
    small_font = load_font(12)

    for sheet_index, start in enumerate(range(0, len(candidates), sheet_size), start=1):
        chunk = candidates[start : start + sheet_size]
        sheet_rows = max(1, (len(chunk) + cols - 1) // cols)
        width = margin * 2 + cols * thumb_w + (cols - 1) * gap
        height = margin * 2 + sheet_rows * (thumb_h + label_h) + (sheet_rows - 1) * gap
        canvas = Image.new("RGB", (width, height), "#f7faf7")
        draw = ImageDraw.Draw(canvas)

        for offset, candidate in enumerate(chunk):
            col = offset % cols
            row = offset // cols
            x = margin + col * (thumb_w + gap)
            y = margin + row * (thumb_h + label_h + gap)
            box = (x, y, x + thumb_w, y + thumb_h)
            try:
                image = Image.open(candidate.staged_path)
                image = ImageOps.exif_transpose(image)
                image.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
                background = Image.new("RGB", (thumb_w, thumb_h), "#e8eee9")
                paste_x = (thumb_w - image.width) // 2
                paste_y = (thumb_h - image.height) // 2
                background.paste(image.convert("RGB"), (paste_x, paste_y))
                canvas.paste(background, box[:2])
            except Exception as exc:  # noqa: BLE001 - contact sheet should survive bad files.
                draw.rectangle(box, fill="#f2d6d6", outline="#b85c5c")
                draw.text((x + 10, y + 10), f"Image error: {exc}", fill="#5b2424", font=small_font)
            draw.rectangle(box, outline="#cbd5ce", width=1)
            label_y = y + thumb_h + 7
            draw.text((x, label_y), candidate.photo_id, fill="#15201b", font=font)
            draw.text((x, label_y + 22), f"session {candidate.import_session} | {candidate.added_local}", fill="#63716a", font=small_font)

        sheet_path = contact_dir / f"contact-sheet-{sheet_index:02d}.jpg"
        canvas.save(sheet_path, quality=90)
        sheets.append(sheet_path)
    return sheets


def write_review_html(run_root: Path, candidates: list[Candidate], sheets: list[Path]) -> None:
    cards = []
    for candidate in candidates:
        rel_path = Path(candidate.staged_path).relative_to(run_root)
        cards.append(
            f"""
            <article>
              <img src="{html.escape(str(rel_path))}" alt="{html.escape(candidate.photo_id)}">
              <div>
                <strong>{html.escape(candidate.photo_id)}</strong>
                <span>session {html.escape(candidate.import_session)} | added {html.escape(candidate.added_local)}</span>
                <span>{html.escape(candidate.filename)}</span>
              </div>
            </article>
            """
        )
    sheet_links = "".join(
        f'<li><a href="{html.escape(str(sheet.relative_to(run_root)))}">{html.escape(sheet.name)}</a></li>'
        for sheet in sheets
    )
    document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Recent Home Sale Photo Candidates</title>
  <style>
    body {{ margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f7faf7; color: #17211d; }}
    header {{ position: sticky; top: 0; padding: 16px 20px; background: rgba(247,250,247,.96); border-bottom: 1px solid #d8ded9; }}
    h1 {{ margin: 0; font-size: 20px; letter-spacing: 0; }}
    main {{ padding: 20px; }}
    ul {{ columns: 2; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 14px; }}
    article {{ background: white; border: 1px solid #d8ded9; border-radius: 8px; overflow: hidden; }}
    img {{ display: block; width: 100%; aspect-ratio: 4 / 3; object-fit: cover; background: #e8eee9; }}
    article div {{ padding: 10px; }}
    span {{ display: block; color: #66726b; font-size: 12px; overflow-wrap: anywhere; margin-top: 3px; }}
  </style>
</head>
<body>
  <header>
    <h1>Recent Home Sale Photo Candidates</h1>
    <div>{len(candidates)} exported photos | contact sheets ready for triage</div>
  </header>
  <main>
    <h2>Contact Sheets</h2>
    <ul>{sheet_links}</ul>
    <h2>Photo Grid</h2>
    <section class="grid">{''.join(cards)}</section>
  </main>
</body>
</html>
"""
    (run_root / "review-gallery.html").write_text(document, encoding="utf-8")


def main() -> None:
    args = parse_args()
    library = Path(args.photos_library).expanduser()
    output_root = Path(args.output_root).expanduser()
    if not output_root.is_absolute():
        output_root = Path.cwd() / output_root
    run_slug = slugify(args.label)
    run_root = output_root / f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{run_slug}"
    run_root.mkdir(parents=True, exist_ok=True)

    with connect_photos_db(library) as connection:
        rows = query_assets(connection, args.since, args.limit)
    candidates = export_candidates(rows, library, run_root, args.label)
    write_manifests(run_root, candidates, args)
    sheets = make_contact_sheets(run_root, candidates, args.sheet_size)
    write_review_html(run_root, candidates, sheets)
    print(f"Run root: {run_root}")
    print(f"Exported photos: {len(candidates)}")
    print(f"Contact sheets: {len(sheets)}")
    print(f"Review gallery: {run_root / 'review-gallery.html'}")


if __name__ == "__main__":
    main()
