import lyric_decipher.metadata as metadata
from lyric_decipher.metadata import TrackInfo, lookup_published_lyrics, resolve_spotify_track


def test_track_slug_and_display():
    t = TrackInfo(title="Chateau (elan)", artist="him's")
    assert t.slug() == "him-s-chateau-elan"
    assert t.display() == "Chateau (elan) — him's"
    assert TrackInfo().display() == "unknown track"
    assert TrackInfo().slug() == "unknown-track"


def test_resolve_rejects_non_spotify_urls_without_network():
    assert resolve_spotify_track("https://example.com/track/abc") is None


def test_resolve_uses_oembed_title(monkeypatch):
    monkeypatch.setattr(metadata, "_get_json", lambda url, timeout=15: {"title": "Chateau (elan)"})
    info = resolve_spotify_track("https://open.spotify.com/track/7ewmdNM0LTB9MMomRmtFQY?si=x")
    assert info.title == "Chateau (elan)"
    assert info.spotify_url == "https://open.spotify.com/track/7ewmdNM0LTB9MMomRmtFQY"
    assert info.source == "spotify-oembed"


def test_lookup_requires_title():
    assert lookup_published_lyrics(TrackInfo()) is None


def test_lookup_returns_best_plausible_hit(monkeypatch):
    hits = [
        {"id": 9, "trackName": "Totally Different", "artistName": "x",
         "plainLyrics": "nope"},
        {"id": 1, "trackName": "Chateau (elan)", "artistName": "him's",
         "plainLyrics": "some words", "syncedLyrics": "[00:01.00]some words",
         "albumName": "Chateau (elan)", "duration": 94},
    ]
    monkeypatch.setattr(metadata, "_get_json", lambda url, timeout=15: hits)
    ref = lookup_published_lyrics(TrackInfo(title="Chateau (elan)", artist="him's"))
    assert ref is not None
    assert ref.plain == "some words"
    assert ref.detail["id"] == 1


def test_lookup_handles_network_failure(monkeypatch):
    def boom(url, timeout=15):
        raise OSError("offline")

    monkeypatch.setattr(metadata, "_get_json", boom)
    assert lookup_published_lyrics(TrackInfo(title="Anything")) is None


def test_lookup_ignores_empty_hits(monkeypatch):
    monkeypatch.setattr(metadata, "_get_json", lambda url, timeout=15: [])
    assert lookup_published_lyrics(TrackInfo(title="Anything")) is None


def test_lookup_rejects_hits_with_empty_or_unrelated_names(monkeypatch):
    hits = [
        {"id": 1, "trackName": "", "plainLyrics": "junk"},
        {"id": 2, "trackName": "Completely Unrelated", "plainLyrics": "junk"},
    ]
    monkeypatch.setattr(metadata, "_get_json", lambda url, timeout=15: hits)
    assert lookup_published_lyrics(TrackInfo(title="Chateau (elan)")) is None
