#!/usr/bin/env python3
"""Assert the smoke run produced outputs and recovered most of the known vocal."""

import json
import re
import sys
from pathlib import Path

work = Path(sys.argv[1])
expected_words = set(re.findall(r"[a-z']+", sys.argv[2].lower()))

runs = sorted(p for p in (work / "runs").iterdir() if p.is_dir() and p.name != "latest")
assert runs, "no run directory was created"
run = runs[-1]

for name in ("lyrics.txt", "lyrics.lrc", "lyrics.srt", "report.md", "report.json"):
    assert (run / name).exists(), f"missing output: {name}"

report = json.loads((run / "report.json").read_text())
assert len(report["passes"]) >= 2, "expected at least two transcription passes"

heard = set(re.findall(r"[a-z']+", (run / "lyrics.txt").read_text().lower()))
stop = {"the", "a", "while", "away"}
targets = expected_words - stop
hits = targets & heard
recall = len(hits) / len(targets)
print(f"keyword recall: {len(hits)}/{len(targets)} ({recall:.0%}) — heard: {sorted(hits)}")
assert recall >= 0.5, f"recall too low; missing {sorted(targets - heard)}"
