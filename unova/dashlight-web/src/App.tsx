import {
  startTransition,
  useDeferredValue,
  useEffect,
  useEffectEvent,
  useState,
} from "react";
import {
  failureModes,
  gimmicks,
  moods,
  palettes,
  sectionPresets,
  speeds,
  type FailureMode,
  type GimmickOption,
  type MoodOption,
  type PaletteOption,
  type SectionPreset,
  type SpeedOption,
} from "./data";

type Attempt = {
  id: number;
  sectionId: string;
  failureId: string;
  confidence: number;
  stress: number;
  note: string;
  createdAt: string;
};

type CoachResponse = {
  status: string;
  headline: string;
  summary: string;
  bullets: string[];
  ritual: string;
};

type IdeaCard = {
  id: number;
  title: string;
  pitch: string;
  mantra: string;
  timeline: string[];
  buildNotes: string[];
  paletteId: string;
};

type PreviewState = {
  mode: "idle" | "countdown" | "cueing" | "complete";
  step: number;
};

function average(values: number[]): number {
  if (values.length === 0) {
    return 0;
  }

  return values.reduce((total, value) => total + value, 0) / values.length;
}

function findFailureMode(failureId: string): FailureMode {
  return (
    failureModes.find((entry) => entry.id === failureId) ?? failureModes[0]
  );
}

function findSection(sectionId: string): SectionPreset {
  return (
    sectionPresets.find((entry) => entry.id === sectionId) ?? sectionPresets[0]
  );
}

function findMood(moodId: string): MoodOption {
  return moods.find((entry) => entry.id === moodId) ?? moods[0];
}

function findSpeed(speedId: string): SpeedOption {
  return speeds.find((entry) => entry.id === speedId) ?? speeds[0];
}

function findGimmick(gimmickId: string): GimmickOption {
  return gimmicks.find((entry) => entry.id === gimmickId) ?? gimmicks[0];
}

function findPalette(paletteId: string): PaletteOption {
  return palettes.find((entry) => entry.id === paletteId) ?? palettes[0];
}

function buildCoachResponse(
  section: SectionPreset,
  attempts: Attempt[],
  calmMode: boolean,
  voiceMode: boolean,
): CoachResponse {
  if (attempts.length === 0) {
    return {
      status: "No attempts logged yet",
      headline: `Start with ${section.label.toLowerCase()} and keep the lane readable.`,
      summary: `${section.focus} ${section.coachHint}`,
      bullets: [
        `Use this mantra: ${section.cues.join(" / ")}.`,
        `Practice only ${section.length.toLowerCase()} before extending the loop.`,
        `If the section spikes stress, strip out one cue and repeat the clean version.`,
      ],
      ritual: voiceMode
        ? "Say it out loud: calm eyes, one beat, one move."
        : "Visible state matters. Keep the next cue larger than the panic.",
    };
  }

  const counts = attempts.reduce<Record<string, number>>(
    (accumulator, attempt) => {
      accumulator[attempt.failureId] =
        (accumulator[attempt.failureId] ?? 0) + 1;
      return accumulator;
    },
    {},
  );
  const dominantFailure = failureModes.reduce((current, candidate) => {
    const currentCount = counts[current.id] ?? 0;
    const candidateCount = counts[candidate.id] ?? 0;

    return candidateCount > currentCount ? candidate : current;
  }, failureModes[0]);
  const confidenceAverage = average(
    attempts.map((attempt) => attempt.confidence),
  );
  const stressAverage = average(attempts.map((attempt) => attempt.stress));
  const recentAttempt = attempts[attempts.length - 1];
  const stressCue =
    stressAverage >= 4
      ? "Drop the loop to the last 3 inputs and mute the extra visual noise."
      : "Keep the whole loop, but only track one cue word per input.";
  const confidenceCue =
    confidenceAverage <= 2.5
      ? "Confidence is still low, so teach the rhythm before adding speed."
      : "Confidence is rising. Keep the cues identical and chase consistency.";

  return {
    status: `${attempts.length} rescue attempts logged`,
    headline: `${dominantFailure.label} is the real blocker in ${section.label.toLowerCase()}.`,
    summary: `${dominantFailure.description} ${dominantFailure.rescueCue}`,
    bullets: [
      stressCue,
      confidenceCue,
      recentAttempt.note
        ? `Last note: "${recentAttempt.note}". Use it as the next rehearsal target.`
        : `Builder clue: ${dominantFailure.buildFix}`,
    ],
    ritual: voiceMode
      ? `Voice line: breathe, ${section.cues[0].toLowerCase()}, then ${dominantFailure.label.toLowerCase()} cleanup.`
      : calmMode
        ? "Calm mode stays on. Fewer cues, bigger timing windows, same rhythm."
        : "Run it hot if you want, but keep the cues identical each pass.",
  };
}

function createIdea(
  section: SectionPreset,
  prompt: string,
  moodId: string,
  speedId: string,
  gimmickId: string,
  paletteId: string,
): IdeaCard {
  const mood = findMood(moodId);
  const speed = findSpeed(speedId);
  const gimmick = findGimmick(gimmickId);
  const palette = findPalette(paletteId);
  const cleanedPrompt = prompt.trim();
  const brief =
    cleanedPrompt.length > 0
      ? cleanedPrompt
      : "A section that feels bold, teachable, and exciting without becoming visual chaos.";

  return {
    id: Date.now(),
    title: `${mood.label} ${gimmick.label} ${section.label}`,
    pitch: `${brief} Shape it as a ${speed.feel} lane with ${mood.flavor} and ${gimmick.flavor}.`,
    mantra: `${mood.mantra}. ${speed.mantra}.`,
    timeline: [
      `Intro: teach ${section.label.toLowerCase()} with ${section.focus.toLowerCase()}`,
      `Pressure rise: ${gimmick.fakeOut}`,
      `Mid-section pivot: swap into ${gimmick.flavor} while preserving the same beat count`,
      `Release: ${gimmick.payoff}`,
      `Finale: echo the palette texture of ${palette.texture} and give the player a clean win`,
    ],
    buildNotes: [
      `Keep the section ${section.intensity.toLowerCase()} until the main gimmick arrives.`,
      `Use ${palette.label.toLowerCase()} so the hazard and safe lane never blend together.`,
      `Make the first hazard teach the idea before the harder version appears.`,
      `Save one wide platform or open corridor at the end so the section feels generous.`,
    ],
    paletteId,
  };
}

export default function App() {
  const [selectedSectionId, setSelectedSectionId] = useState(
    sectionPresets[0].id,
  );
  const [selectedFailureId, setSelectedFailureId] = useState(
    failureModes[0].id,
  );
  const [confidence, setConfidence] = useState(2);
  const [stress, setStress] = useState(3);
  const [attemptNote, setAttemptNote] = useState("");
  const [voiceMode, setVoiceMode] = useState(true);
  const [calmMode, setCalmMode] = useState(true);
  const [attempts, setAttempts] = useState<Attempt[]>([]);
  const [previewState, setPreviewState] = useState<PreviewState>({
    mode: "idle",
    step: 0,
  });

  const [builderPrompt, setBuilderPrompt] = useState(
    "A neon canyon section with one dramatic fake-out and a big satisfying release.",
  );
  const [selectedMoodId, setSelectedMoodId] = useState(moods[0].id);
  const [selectedSpeedId, setSelectedSpeedId] = useState(speeds[1].id);
  const [selectedGimmickId, setSelectedGimmickId] = useState(gimmicks[2].id);
  const [selectedPaletteId, setSelectedPaletteId] = useState(palettes[0].id);
  const [activeIdea, setActiveIdea] = useState<IdeaCard>(() =>
    createIdea(
      sectionPresets[0],
      "A neon canyon section with one dramatic fake-out and a big satisfying release.",
      moods[0].id,
      speeds[1].id,
      gimmicks[2].id,
      palettes[0].id,
    ),
  );
  const [savedIdeas, setSavedIdeas] = useState<IdeaCard[]>([]);
  const [ideaSearch, setIdeaSearch] = useState("");

  const selectedSection = findSection(selectedSectionId);
  const sectionAttempts = attempts.filter(
    (attempt) => attempt.sectionId === selectedSectionId,
  );
  const coach = buildCoachResponse(
    selectedSection,
    sectionAttempts,
    calmMode,
    voiceMode,
  );
  const activePalette = findPalette(activeIdea.paletteId);
  const deferredIdeaSearch = useDeferredValue(ideaSearch.trim().toLowerCase());
  const filteredIdeas = savedIdeas.filter((idea) => {
    if (!deferredIdeaSearch) {
      return true;
    }

    const haystack = [
      idea.title,
      idea.pitch,
      idea.mantra,
      ...idea.timeline,
      ...idea.buildNotes,
    ]
      .join(" ")
      .toLowerCase();

    return haystack.includes(deferredIdeaSearch);
  });
  const countdownLabels = ["3", "2", "1"];
  const previewLabels =
    previewState.mode === "cueing" || previewState.mode === "complete"
      ? selectedSection.cues
      : countdownLabels;
  const currentPreviewLabel =
    previewLabels[previewState.step] ?? previewLabels[0];
  const previewStatus =
    previewState.mode === "idle"
      ? "Ready"
      : previewState.mode === "countdown"
        ? "Counting in"
        : previewState.mode === "cueing"
          ? "Cueing live"
          : "Complete";

  const advancePreview = useEffectEvent(() => {
    setPreviewState((current) => {
      if (current.mode === "countdown") {
        if (current.step < countdownLabels.length - 1) {
          return { mode: "countdown", step: current.step + 1 };
        }

        return { mode: "cueing", step: 0 };
      }

      if (current.mode === "cueing") {
        if (current.step < selectedSection.cues.length - 1) {
          return { mode: "cueing", step: current.step + 1 };
        }

        return { mode: "complete", step: selectedSection.cues.length - 1 };
      }

      return current;
    });
  });

  const stopPreview = useEffectEvent(() => {
    setPreviewState({ mode: "idle", step: 0 });
  });

  useEffect(() => {
    if (previewState.mode === "idle" || previewState.mode === "complete") {
      return undefined;
    }

    const timer = window.setTimeout(
      () => {
        advancePreview();
      },
      calmMode ? 1100 : 820,
    );

    return () => {
      window.clearTimeout(timer);
    };
  }, [advancePreview, calmMode, previewState.mode, previewState.step]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        stopPreview();
      }
    };

    window.addEventListener("keydown", handleKeyDown);

    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [stopPreview]);

  useEffect(() => {
    setPreviewState({ mode: "idle", step: 0 });
  }, [selectedSectionId]);

  function handleGenerateIdea() {
    startTransition(() => {
      setActiveIdea(
        createIdea(
          selectedSection,
          builderPrompt,
          selectedMoodId,
          selectedSpeedId,
          selectedGimmickId,
          selectedPaletteId,
        ),
      );
    });
  }

  function handleLogAttempt() {
    setAttempts((current) => [
      {
        id: Date.now(),
        sectionId: selectedSectionId,
        failureId: selectedFailureId,
        confidence,
        stress,
        note: attemptNote.trim(),
        createdAt: new Date().toLocaleTimeString([], {
          hour: "numeric",
          minute: "2-digit",
        }),
      },
      ...current,
    ]);
    setAttemptNote("");
  }

  function handleSaveIdea() {
    setSavedIdeas((current) => [
      {
        ...activeIdea,
        id: Date.now(),
      },
      ...current,
    ]);
  }

  return (
    <div className="app-shell">
      <div className="grid-overlay" aria-hidden="true" />

      <header className="topbar">
        <div className="brand-block">
          <p className="brand">Dashlight</p>
          <p className="brand-subtitle">
            Rescue the hard part. Build the wild part.
          </p>
        </div>
        <div className="mode-row" aria-label="Experience toggles">
          <button
            className={voiceMode ? "mode-pill is-active" : "mode-pill"}
            onClick={() => setVoiceMode((current) => !current)}
            type="button"
          >
            Voice prompts {voiceMode ? "on" : "off"}
          </button>
          <button
            className={calmMode ? "mode-pill is-active" : "mode-pill"}
            onClick={() => setCalmMode((current) => !current)}
            type="button"
          >
            Calm mode {calmMode ? "on" : "off"}
          </button>
        </div>
      </header>

      <main className="page">
        <section className="hero">
          <div className="hero-copy">
            <p className="eyebrow">Geometry Dash helper v1</p>
            <h1>Build him a coach, not a ghost pilot.</h1>
            <p className="lede">
              Dashlight turns a rough section into a repeatable rescue loop,
              then turns level ideas into concrete builds he can own.
            </p>
            <div className="hero-actions">
              <a className="action action-primary" href="#rescue">
                Start rescue loop
              </a>
              <a className="action action-secondary" href="#builder">
                Generate a section
              </a>
            </div>
          </div>

          <div className="hero-rail">
            <div className="status-stack">
              <div>
                <span>State</span>
                <strong>{previewStatus}</strong>
              </div>
              <div>
                <span>Segment</span>
                <strong>{selectedSection.label}</strong>
              </div>
              <div>
                <span>Safety</span>
                <strong>Escape stops cues instantly</strong>
              </div>
            </div>
            <p className="rail-copy">
              Low surprise, visible state, and short loops. That is the whole
              philosophy.
            </p>
          </div>
        </section>

        <section className="workspace-grid" id="rescue">
          <div className="section-heading">
            <p className="eyebrow">Practice rescue</p>
            <h2>Track the blocker, coach the rhythm, preview the cues.</h2>
          </div>

          <div className="panel rescue-panel">
            <div className="panel-head">
              <div>
                <p className="panel-kicker">Segment presets</p>
                <h3>{selectedSection.label}</h3>
              </div>
              <p className="panel-meta">
                {selectedSection.lane} · {selectedSection.difficulty}
              </p>
            </div>

            <div className="chip-row" aria-label="Section presets">
              {sectionPresets.map((section) => (
                <button
                  key={section.id}
                  className={
                    section.id === selectedSectionId ? "chip is-active" : "chip"
                  }
                  onClick={() => {
                    startTransition(() => {
                      setSelectedSectionId(section.id);
                    });
                  }}
                  type="button"
                >
                  {section.label}
                </button>
              ))}
            </div>

            <div className="detail-strip">
              <div>
                <span>Length</span>
                <strong>{selectedSection.length}</strong>
              </div>
              <div>
                <span>Focus</span>
                <strong>{selectedSection.intensity}</strong>
              </div>
              <div>
                <span>Hint</span>
                <strong>{selectedSection.coachHint}</strong>
              </div>
            </div>

            <div className="control-grid">
              <label className="field">
                <span>What went wrong?</span>
                <div className="chip-row">
                  {failureModes.map((failure) => (
                    <button
                      key={failure.id}
                      className={
                        failure.id === selectedFailureId
                          ? "chip is-active"
                          : "chip"
                      }
                      onClick={() => setSelectedFailureId(failure.id)}
                      type="button"
                    >
                      {failure.label}
                    </button>
                  ))}
                </div>
              </label>

              <label className="field">
                <span>Confidence</span>
                <div className="slider-row">
                  <input
                    max="5"
                    min="1"
                    onChange={(event) =>
                      setConfidence(Number(event.target.value))
                    }
                    type="range"
                    value={confidence}
                  />
                  <strong>{confidence}/5</strong>
                </div>
              </label>

              <label className="field">
                <span>Stress</span>
                <div className="slider-row">
                  <input
                    max="5"
                    min="1"
                    onChange={(event) => setStress(Number(event.target.value))}
                    type="range"
                    value={stress}
                  />
                  <strong>{stress}/5</strong>
                </div>
              </label>

              <label className="field">
                <span>Quick note</span>
                <textarea
                  onChange={(event) => setAttemptNote(event.target.value)}
                  placeholder="Example: I panic after the pink orb and tap twice."
                  rows={3}
                  value={attemptNote}
                />
              </label>
            </div>

            <div className="action-row">
              <button
                className="action action-primary"
                onClick={handleLogAttempt}
                type="button"
              >
                Log attempt
              </button>
              <button
                className="action action-secondary"
                onClick={() => setPreviewState({ mode: "countdown", step: 0 })}
                type="button"
              >
                Run cue preview
              </button>
              <button
                className="action action-secondary"
                onClick={stopPreview}
                type="button"
              >
                Stop
              </button>
            </div>
          </div>

          <div className="panel coach-panel">
            <div className="panel-head">
              <div>
                <p className="panel-kicker">Coach board</p>
                <h3>{coach.headline}</h3>
              </div>
              <p className="panel-meta">{coach.status}</p>
            </div>

            <p className="coach-summary">{coach.summary}</p>

            <div className="cue-monitor">
              <div className={`cue-screen cue-screen-${previewState.mode}`}>
                <span className="cue-label">{previewStatus}</span>
                <strong>{currentPreviewLabel}</strong>
                <p>Escape always cancels the loop.</p>
              </div>
              <div className="cue-sequence">
                {selectedSection.cues.map((cue, index) => (
                  <span
                    key={cue}
                    className={
                      previewState.mode === "cueing" &&
                      index === previewState.step
                        ? "cue-tag is-live"
                        : "cue-tag"
                    }
                  >
                    {cue}
                  </span>
                ))}
              </div>
            </div>

            <ul className="coach-list">
              {coach.bullets.map((bullet) => (
                <li key={bullet}>{bullet}</li>
              ))}
            </ul>

            <p className="ritual-line">{coach.ritual}</p>

            <div className="attempt-log">
              <p className="panel-kicker">Recent attempts</p>
              {sectionAttempts.length === 0 ? (
                <p className="empty-copy">
                  No attempts yet. Log one failed pass and Dashlight will narrow
                  the blocker for you.
                </p>
              ) : (
                <div className="attempt-grid">
                  {sectionAttempts.slice(0, 4).map((attempt) => (
                    <article key={attempt.id} className="attempt-card">
                      <strong>
                        {findFailureMode(attempt.failureId).label}
                      </strong>
                      <span>
                        confidence {attempt.confidence}/5 · stress{" "}
                        {attempt.stress}/5
                      </span>
                      <p>
                        {attempt.note ||
                          "No note added. Use the failure pattern only."}
                      </p>
                      <em>{attempt.createdAt}</em>
                    </article>
                  ))}
                </div>
              )}
            </div>
          </div>
        </section>

        <section className="builder-grid" id="builder">
          <div className="section-heading">
            <p className="eyebrow">Builder companion</p>
            <h2>Turn a cool idea into a section plan he can actually build.</h2>
          </div>

          <div className="panel builder-panel">
            <div className="panel-head">
              <div>
                <p className="panel-kicker">Build controls</p>
                <h3>Prompt and tune the section</h3>
              </div>
              <p className="panel-meta">Text first, voice later</p>
            </div>

            <label className="field">
              <span>What should the section feel like?</span>
              <textarea
                onChange={(event) => setBuilderPrompt(event.target.value)}
                rows={4}
                value={builderPrompt}
              />
            </label>

            <label className="field">
              <span>Mood</span>
              <div className="chip-row">
                {moods.map((mood) => (
                  <button
                    key={mood.id}
                    className={
                      mood.id === selectedMoodId ? "chip is-active" : "chip"
                    }
                    onClick={() => setSelectedMoodId(mood.id)}
                    type="button"
                  >
                    {mood.label}
                  </button>
                ))}
              </div>
            </label>

            <label className="field">
              <span>Speed</span>
              <div className="chip-row">
                {speeds.map((speed) => (
                  <button
                    key={speed.id}
                    className={
                      speed.id === selectedSpeedId ? "chip is-active" : "chip"
                    }
                    onClick={() => setSelectedSpeedId(speed.id)}
                    type="button"
                  >
                    {speed.label}
                  </button>
                ))}
              </div>
            </label>

            <label className="field">
              <span>Gimmick</span>
              <div className="chip-row">
                {gimmicks.map((gimmick) => (
                  <button
                    key={gimmick.id}
                    className={
                      gimmick.id === selectedGimmickId
                        ? "chip is-active"
                        : "chip"
                    }
                    onClick={() => setSelectedGimmickId(gimmick.id)}
                    type="button"
                  >
                    {gimmick.label}
                  </button>
                ))}
              </div>
            </label>

            <label className="field">
              <span>Palette</span>
              <div className="chip-row">
                {palettes.map((palette) => (
                  <button
                    key={palette.id}
                    className={
                      palette.id === selectedPaletteId
                        ? "chip is-active"
                        : "chip"
                    }
                    onClick={() => setSelectedPaletteId(palette.id)}
                    type="button"
                  >
                    {palette.label}
                  </button>
                ))}
              </div>
            </label>

            <div className="action-row">
              <button
                className="action action-primary"
                onClick={handleGenerateIdea}
                type="button"
              >
                Generate section
              </button>
              <button
                className="action action-secondary"
                onClick={handleSaveIdea}
                type="button"
              >
                Save idea
              </button>
            </div>
          </div>

          <div className="panel idea-panel">
            <div className="panel-head">
              <div>
                <p className="panel-kicker">Generated build</p>
                <h3>{activeIdea.title}</h3>
              </div>
              <p className="panel-meta">{selectedSection.label}</p>
            </div>

            <p className="idea-pitch">{activeIdea.pitch}</p>
            <p className="ritual-line">{activeIdea.mantra}</p>

            <div className="palette-strip" aria-label="Suggested palette">
              {activePalette.colors.map((color) => (
                <span
                  key={color}
                  className="swatch"
                  style={{ backgroundColor: color }}
                />
              ))}
            </div>

            <div className="timeline-grid">
              {activeIdea.timeline.map((step) => (
                <article key={step} className="timeline-step">
                  <p>{step}</p>
                </article>
              ))}
            </div>

            <ul className="coach-list">
              {activeIdea.buildNotes.map((note) => (
                <li key={note}>{note}</li>
              ))}
            </ul>
          </div>
        </section>

        <section className="saved-section">
          <div className="section-heading">
            <p className="eyebrow">Saved ideas</p>
            <h2>Keep the sparks that feel worth building later.</h2>
          </div>

          <div className="panel saved-panel">
            <label className="field field-inline">
              <span>Search saved ideas</span>
              <input
                onChange={(event) => setIdeaSearch(event.target.value)}
                placeholder="Find a mood, gimmick, or build note"
                type="search"
                value={ideaSearch}
              />
            </label>

            {filteredIdeas.length === 0 ? (
              <p className="empty-copy">
                Save an idea and it will land here as a reusable build card.
              </p>
            ) : (
              <div className="saved-grid">
                {filteredIdeas.map((idea) => (
                  <article key={idea.id} className="saved-idea">
                    <strong>{idea.title}</strong>
                    <p>{idea.pitch}</p>
                    <em>{idea.mantra}</em>
                  </article>
                ))}
              </div>
            )}
          </div>
        </section>
      </main>
    </div>
  );
}
