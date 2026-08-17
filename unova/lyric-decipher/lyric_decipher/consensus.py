"""Cross-pass consensus: agree where passes agree, flag where they don't.

The primary pass (highest duration-weighted word probability) provides the
line structure and timing. Every primary word is then checked against the
other passes by time overlap:

- words the model was sure of AND other passes reproduced → trusted
- everything else → flagged, with the alternatives the other passes heard,
  so a human can ear-check exactly that second of audio instead of
  re-listening to the whole song.

This never invents text: the output is always something a pass actually
heard, annotated with how much to trust it.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from .transcribe import PassResult, Word

PROB_FLOOR = 0.45        # model-confidence floor before a word gets flagged
AGREEMENT_FLOOR = 0.5    # fraction of comparison passes that must agree
OVERLAP_SLACK = 0.25     # seconds of timing slack when matching words across passes


def normalize_word(text: str) -> str:
    return re.sub(r"[^\w']+", "", text.lower()).strip("'")


@dataclass
class ConsensusWord:
    word: Word
    agreement: float          # 0..1 across passes that had a word here; 1.0 if unopposed
    votes: int                # passes with any overlapping word
    flagged: bool
    alternatives: list[tuple[str, int]] = field(default_factory=list)


@dataclass
class ConsensusLine:
    start: float
    end: float
    words: list[ConsensusWord]

    @property
    def text(self) -> str:
        return " ".join(cw.word.text for cw in self.words)

    def marked_text(self) -> str:
        parts = []
        for cw in self.words:
            parts.append(f"[{cw.word.text}?]" if cw.flagged else cw.word.text)
        return " ".join(parts)


@dataclass
class ConsensusResult:
    primary: str
    lines: list[ConsensusLine]
    passes: list[PassResult]

    @property
    def words(self) -> list[ConsensusWord]:
        return [w for line in self.lines for w in line.words]

    def flagged_words(self) -> list[ConsensusWord]:
        return [w for w in self.words if w.flagged]

    def overall_confidence(self) -> float:
        words = self.words
        if not words:
            return 0.0
        return sum(cw.word.prob * (0.5 + 0.5 * cw.agreement) for cw in words) / len(words)


def _overlapping(word: Word, candidates: list[Word]) -> Word | None:
    """Best time-overlapping candidate for `word`, or None."""
    best: Word | None = None
    best_overlap = 0.0
    lo, hi = word.start - OVERLAP_SLACK, word.end + OVERLAP_SLACK
    for cand in candidates:
        if cand.end < lo or cand.start > hi:
            continue
        overlap = min(word.end, cand.end) - max(word.start, cand.start)
        # midpoint containment rescues zero-duration overlaps within the slack
        if overlap <= 0 and not (lo <= cand.mid <= hi):
            continue
        if overlap > best_overlap or best is None:
            best, best_overlap = cand, max(overlap, 0.0)
    return best


def build_consensus(passes: list[PassResult]) -> ConsensusResult:
    if not passes:
        raise ValueError("no transcription passes to merge")
    ranked = sorted(passes, key=lambda p: p.score(), reverse=True)
    primary = ranked[0]
    others = ranked[1:]
    other_words = [p.words for p in others]

    lines: list[ConsensusLine] = []
    for line in primary.lines:
        cwords: list[ConsensusWord] = []
        for word in line.words:
            norm = normalize_word(word.text)
            votes = 0
            agree = 0
            alt_counts: dict[str, int] = {}
            alt_display: dict[str, str] = {}
            for pool in other_words:
                match = _overlapping(word, pool)
                if match is None:
                    continue
                votes += 1
                match_norm = normalize_word(match.text)
                if match_norm == norm:
                    agree += 1
                elif match_norm:
                    alt_counts[match_norm] = alt_counts.get(match_norm, 0) + 1
                    alt_display.setdefault(match_norm, match.text)
            agreement = agree / votes if votes else 1.0
            flagged = bool(word.prob < PROB_FLOOR or (votes > 0 and agreement < AGREEMENT_FLOOR))
            alternatives = sorted(
                ((alt_display[k], n) for k, n in alt_counts.items()),
                key=lambda kv: (-kv[1], kv[0]),
            )
            cwords.append(
                ConsensusWord(
                    word=word,
                    agreement=agreement,
                    votes=votes,
                    flagged=flagged,
                    alternatives=alternatives,
                )
            )
        if cwords:
            lines.append(ConsensusLine(start=line.start, end=line.end, words=cwords))
    return ConsensusResult(primary=primary.name, lines=lines, passes=passes)
