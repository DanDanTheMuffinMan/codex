"""Track metadata resolution and published-lyrics lookup.

Two network helpers, both against open unauthenticated endpoints:

- Spotify oEmbed (https://open.spotify.com/oembed) resolves a pasted track link
  to a display title without needing API credentials. It never touches audio.
- LRCLIB (https://lrclib.net) is an open, liberally licensed lyrics database.
  We check it first so we only spend transcription effort on tracks whose
  lyrics genuinely are not published anywhere.

Both helpers fail soft: any network or parse error returns None so the
pipeline can continue offline.
"""

from __future__ import annotations

import json
import re
import urllib.parse
import urllib.request
from dataclasses import dataclass, field

USER_AGENT = "unova-lyric-decipher/0.1 (personal use)"
DEFAULT_TIMEOUT = 15


@dataclass
class TrackInfo:
    title: str | None = None
    artist: str | None = None
    spotify_url: str | None = None
    source: str = "manual"

    def slug(self) -> str:
        base = " ".join(p for p in (self.artist, self.title) if p) or "unknown-track"
        base = base.lower()
        base = re.sub(r"[^a-z0-9]+", "-", base).strip("-")
        return base[:60] or "unknown-track"

    def display(self) -> str:
        if self.artist and self.title:
            return f"{self.title} — {self.artist}"
        return self.title or self.artist or "unknown track"


@dataclass
class ReferenceLyrics:
    source: str
    plain: str | None = None
    synced: str | None = None
    instrumental: bool = False
    detail: dict = field(default_factory=dict)


def _get_json(url: str, timeout: int = DEFAULT_TIMEOUT):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def resolve_spotify_track(url: str) -> TrackInfo | None:
    """Resolve a Spotify track URL to title/artist via the public oEmbed endpoint.

    oEmbed only exposes a display title (usually "Title" or "Title (mix)"), not
    a separate artist field, so the artist may stay None and can be filled in
    with --artist.
    """
    if "open.spotify.com" not in url:
        return None
    clean = url.split("?")[0]
    oembed = "https://open.spotify.com/oembed?url=" + urllib.parse.quote(clean, safe="")
    try:
        data = _get_json(oembed)
    except Exception:
        return None
    title = (data.get("title") or "").strip() or None
    return TrackInfo(title=title, artist=None, spotify_url=clean, source="spotify-oembed")


def lookup_published_lyrics(track: TrackInfo) -> ReferenceLyrics | None:
    """Search LRCLIB for already-published lyrics for this track.

    Returns the best hit, or None when nothing plausible is published — which
    for this pack's target material (tiny artists, unreleased mixes) is the
    common case and the signal to transcribe.
    """
    if not track.title:
        return None
    params = {"track_name": track.title}
    if track.artist:
        params["artist_name"] = track.artist
    url = "https://lrclib.net/api/search?" + urllib.parse.urlencode(params)
    try:
        hits = _get_json(url)
    except Exception:
        return None
    if not isinstance(hits, list) or not hits:
        return None

    def plausible(hit: dict) -> bool:
        name = (hit.get("trackName") or "").lower()
        return bool(name) and _norm(track.title) in _norm(name) or _norm(name) in _norm(track.title)

    ranked = [h for h in hits if isinstance(h, dict) and plausible(h)]
    if not ranked:
        return None
    best = ranked[0]
    plain = best.get("plainLyrics") or None
    synced = best.get("syncedLyrics") or None
    instrumental = bool(best.get("instrumental"))
    if not plain and not synced and not instrumental:
        return None
    return ReferenceLyrics(
        source="lrclib",
        plain=plain,
        synced=synced,
        instrumental=instrumental,
        detail={
            "id": best.get("id"),
            "trackName": best.get("trackName"),
            "artistName": best.get("artistName"),
            "albumName": best.get("albumName"),
            "duration": best.get("duration"),
        },
    )


def _norm(text: str | None) -> str:
    return re.sub(r"[^a-z0-9]+", " ", (text or "").lower()).strip()
