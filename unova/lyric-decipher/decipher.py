#!/usr/bin/env python3
"""Launcher so the pack runs from anywhere: python3 unova/lyric-decipher/decipher.py …"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lyric_decipher.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
