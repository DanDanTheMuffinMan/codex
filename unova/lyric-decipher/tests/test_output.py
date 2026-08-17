import json

from lyric_decipher.consensus import build_consensus
from lyric_decipher.metadata import ReferenceLyrics, TrackInfo
from lyric_decipher.output import make_run_dir, write_outputs, write_reference_only
from lyric_decipher.transcribe import Line, PassResult, Word


def _consensus():
    words = [
        Word(start=0.0, end=0.5, text="Golden", prob=0.9),
        Word(start=0.5, end=1.0, text="hour", prob=0.9),
        Word(start=1.2, end=1.6, text="fades", prob=0.2),
    ]
    line = Line(start=0.0, end=1.6, text="Golden hour fades", words=words, avg_logprob=-0.2)
    p = PassResult(name="enhanced/beam5", variant="enhanced", config="beam5",
                   language="en", language_prob=0.98, lines=[line])
    return build_consensus([p])


def test_make_run_dir_creates_stamped_dir_and_latest_symlink(tmp_path):
    run_dir = make_run_dir(tmp_path, "himns-chateau")
    assert run_dir.is_dir()
    assert run_dir.name.endswith("-himns-chateau")
    latest = tmp_path / "runs" / "latest"
    assert latest.is_symlink()
    assert (latest / ".").resolve() == run_dir.resolve()


def test_write_outputs_produces_all_files(tmp_path):
    track = TrackInfo(title="Chateau (elan)", artist="him's",
                      spotify_url="https://open.spotify.com/track/x")
    run_dir = make_run_dir(tmp_path, track.slug())
    written = write_outputs(run_dir, track, _consensus(), None,
                            audio_notes=[{"name": "enhanced"}],
                            settings={"model": "small"})
    assert set(written) == {"lyrics.txt", "lyrics.lrc", "lyrics.srt", "report.md", "report.json"}

    txt = written["lyrics.txt"].read_text()
    assert "Golden hour [fades?]" in txt
    assert "Chateau (elan) — him's" in txt

    lrc = written["lyrics.lrc"].read_text()
    assert "[ti:Chateau (elan)]" in lrc
    assert "[00:00.00]Golden hour fades" in lrc

    srt = written["lyrics.srt"].read_text()
    assert "00:00:00,000 --> 00:00:01,600" in srt

    report = json.loads(written["report.json"].read_text())
    assert report["track"]["artist"] == "him's"
    assert report["consensus"][0]["words"][2]["flagged"] is True
    assert report["reference_lyrics_found"] is False

    md = written["report.md"].read_text()
    assert "fades" in md and "Words to ear-check" in md


def test_write_outputs_saves_reference_when_found(tmp_path):
    track = TrackInfo(title="Known Song", artist="Someone")
    run_dir = make_run_dir(tmp_path, track.slug())
    ref = ReferenceLyrics(source="lrclib", plain="la la la", synced="[00:01.00]la la la")
    written = write_outputs(run_dir, track, _consensus(), ref,
                            audio_notes=[], settings={})
    assert written["reference.txt"].read_text().strip() == "la la la"
    assert written["reference.lrc"].read_text().startswith("[00:01.00]")


def test_write_reference_only(tmp_path):
    track = TrackInfo(title="Known Song", artist="Someone")
    run_dir = make_run_dir(tmp_path, track.slug())
    ref = ReferenceLyrics(source="lrclib", plain="words", detail={"id": 1})
    written = write_reference_only(run_dir, track, ref)
    assert "reference.txt" in written and "report.json" in written


def test_run_dir_slug_sanitizes_names(tmp_path):
    track = TrackInfo(title="Chateau (elan)!!", artist="him's")
    assert track.slug() == "him-s-chateau-elan"
    run_dir = make_run_dir(tmp_path, track.slug())
    assert " " not in run_dir.name
