from lyric_decipher.consensus import build_consensus, normalize_word
from lyric_decipher.transcribe import Line, PassResult, Word


def _mk_pass(name, word_specs, avg=0.9):
    """word_specs: list of (start, end, text, prob) building one line per 4s window."""
    words = [Word(start=s, end=e, text=t, prob=p) for s, e, t, p in word_specs]
    line = Line(start=words[0].start, end=words[-1].end,
                text=" ".join(w.text for w in words), words=words, avg_logprob=-0.2)
    return PassResult(name=name, variant=name.split("/")[0], config="beam5",
                      language="en", language_prob=0.99, lines=[line])


def test_normalize_word_strips_punctuation_and_case():
    assert normalize_word("Hello,") == "hello"
    assert normalize_word("don't!") == "don't"
    assert normalize_word("...") == ""


def test_primary_is_highest_scoring_pass():
    weak = _mk_pass("original/beam5", [(0, 1, "mumble", 0.3), (1, 2, "words", 0.3)])
    strong = _mk_pass("enhanced/beam5", [(0, 1, "clear", 0.95), (1, 2, "words", 0.95)])
    result = build_consensus([weak, strong])
    assert result.primary == "enhanced/beam5"
    assert result.lines[0].text == "clear words"


def test_agreeing_confident_words_are_not_flagged():
    a = _mk_pass("enhanced/beam5", [(0, 1, "golden", 0.9), (1, 2, "hour", 0.9)])
    b = _mk_pass("original/beam5", [(0, 1, "golden", 0.8), (1, 2, "hour", 0.8)])
    result = build_consensus([a, b])
    assert [w.flagged for w in result.words] == [False, False]
    assert all(w.agreement == 1.0 for w in result.words)


def test_disagreement_flags_word_and_records_alternative():
    a = _mk_pass("enhanced/beam5", [(0, 1, "chateau", 0.9), (1, 2, "nights", 0.9)])
    b = _mk_pass("original/beam5", [(0, 1, "shadow", 0.7), (1, 2, "nights", 0.7)])
    c = _mk_pass("vocals/beam5", [(0, 1, "shallow", 0.7), (1, 2, "nights", 0.7)])
    result = build_consensus([a, b, c])
    first = result.words[0]
    assert first.flagged
    assert first.agreement == 0.0
    alt_texts = {t for t, _ in first.alternatives}
    assert alt_texts == {"shadow", "shallow"}
    assert not result.words[1].flagged


def test_low_probability_word_is_flagged_even_when_unopposed():
    a = _mk_pass("enhanced/beam5", [(0, 1, "whisper", 0.2)])
    result = build_consensus([a])
    assert result.words[0].flagged
    assert result.words[0].votes == 0
    assert result.words[0].agreement == 1.0


def test_marked_text_wraps_flagged_words():
    a = _mk_pass("enhanced/beam5", [(0, 1, "clear", 0.9), (1, 2, "mud", 0.1)])
    result = build_consensus([a])
    assert result.lines[0].marked_text() == "clear [mud?]"


def test_word_matching_respects_time_windows():
    # second pass heard a different word but 10s away — must not count as vote
    a = _mk_pass("enhanced/beam5", [(0, 1, "alone", 0.9)])
    b = _mk_pass("original/beam5", [(10, 11, "again", 0.9)])
    result = build_consensus([a, b])
    assert result.words[0].votes == 0
    assert not result.words[0].flagged


def test_overall_confidence_between_zero_and_one():
    a = _mk_pass("enhanced/beam5", [(0, 1, "la", 0.9), (1, 2, "la", 0.4)])
    b = _mk_pass("original/beam5", [(0, 1, "la", 0.8), (1, 2, "da", 0.5)])
    result = build_consensus([a, b])
    assert 0.0 < result.overall_confidence() <= 1.0
