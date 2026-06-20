import { startTransition, useDeferredValue, useState } from "react";
import {
  cities,
  goals,
  languages,
  phases,
  type CityData,
  type CityId,
  type GoalId,
  type LanguageId,
  type PhaseId,
} from "./data";

type AssistantResponse = {
  eyebrow: string;
  title: string;
  summary: string;
  bullets: string[];
};

function buildAssistantResponse(
  city: CityData,
  goalId: GoalId,
  languageId: LanguageId,
  phaseId: PhaseId,
): AssistantResponse {
  const goal = goals.find((entry) => entry.id === goalId);
  const language = languages.find((entry) => entry.id === languageId);
  const phase = phases.find((entry) => entry.id === phaseId);
  const phrase =
    city.phrases.find((entry) => entry.language === languageId) ?? city.phrases[0];
  const timeline = city.itinerary[phaseId];
  const topLane = city.commerce[0];

  return {
    eyebrow: `${city.shortName} agent mode`,
    title: `${phase?.label ?? "Live"} | ${goal?.label ?? "Fan support"}`,
    summary: `${timeline.note} Lead with ${language?.label ?? "translated"} queue support, then move into ${topLane.label.toLowerCase()} once the fan trusts the route.`,
    bullets: [
      `Open with: "${phrase.native}" and keep "${phrase.english}" visible underneath.`,
      `Push fans toward ${city.zones[0]?.name ?? "the primary zone"} when the goal is ${goal?.hint ?? "clear guidance"}.`,
      `Use ${topLane.label.toLowerCase()} as the first monetization prompt only after the fan has a clear next step.`,
    ],
  };
}

export default function App() {
  const [selectedCityId, setSelectedCityId] = useState<CityId>("kc");
  const [selectedGoalId, setSelectedGoalId] = useState<GoalId>("arrival");
  const [selectedLanguageId, setSelectedLanguageId] =
    useState<LanguageId>("spanish");
  const [selectedPhaseId, setSelectedPhaseId] = useState<PhaseId>("pregame");
  const [search, setSearch] = useState("");

  const city = cities[selectedCityId];
  const deferredSearch = useDeferredValue(search.trim().toLowerCase());
  const assistant = buildAssistantResponse(
    city,
    selectedGoalId,
    selectedLanguageId,
    selectedPhaseId,
  );
  const filteredActivations = city.activations.filter((activation) => {
    if (activation.phase !== selectedPhaseId) {
      return false;
    }

    if (!deferredSearch) {
      return true;
    }

    const haystack = [
      activation.name,
      activation.category,
      activation.description,
      activation.monetization,
      activation.audience,
    ]
      .join(" ")
      .toLowerCase();

    return haystack.includes(deferredSearch);
  });

  return (
    <div className="app-shell" data-city={selectedCityId}>
      <div className="backdrop" aria-hidden="true" />
      <header className="topbar">
        <div>
          <p className="brand-mark">FanFlow '26</p>
          <p className="brand-subtitle">KC pilot. ATL amplifier. Matchday operator.</p>
        </div>
        <nav className="city-switch" aria-label="Select host city">
          {(["kc", "atl"] as CityId[]).map((cityId) => (
            <button
              key={cityId}
              className={cityId === selectedCityId ? "city-chip is-active" : "city-chip"}
              onClick={() => {
                startTransition(() => {
                  setSelectedCityId(cityId);
                });
              }}
              type="button"
            >
              {cities[cityId].shortName}
            </button>
          ))}
        </nav>
      </header>

      <main>
        <section className="hero section">
          <div className="hero-copy">
            <p className="eyebrow">{city.heroLabel}</p>
            <h1>{city.heroTitle}</h1>
            <p className="lede">{city.heroCopy}</p>
            <div className="hero-actions">
              <a className="button button-primary" href="#agent">
                Open agent board
              </a>
              <a className="button button-secondary" href="#commerce">
                View revenue lanes
              </a>
            </div>
          </div>

          <div className="hero-rail">
            <div className="stage-label">
              <p>{city.stageLabel}</p>
              <strong>{city.venueLabel}</strong>
            </div>
            <p className="atmosphere">{city.atmosphere}</p>
            <div className="stat-row">
              {city.stats.map((stat) => (
                <div key={stat.label} className="stat-block">
                  <span>{stat.label}</span>
                  <strong>{stat.value}</strong>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="switchboard section" id="switchboard">
          <div className="section-heading">
            <p className="eyebrow">City switchboard</p>
            <h2>{city.name} live map</h2>
          </div>
          <div className="split-grid">
            <div className="column-panel">
              <p className="panel-kicker">Zone logic</p>
              <ul className="zone-list">
                {city.zones.map((zone) => (
                  <li key={zone.name}>
                    <div>
                      <strong>{zone.name}</strong>
                      <span>{zone.distance}</span>
                    </div>
                    <p>{zone.bestFor}</p>
                    <em>{zone.mood}</em>
                  </li>
                ))}
              </ul>
            </div>

            <div className="column-panel">
              <p className="panel-kicker">Sponsor-facing surfaces</p>
              <div className="sponsor-stack">
                {city.sponsors.map((sponsor) => (
                  <span key={sponsor}>{sponsor}</span>
                ))}
              </div>
              <div className="timeline-note">
                <p className="panel-kicker">Current phase</p>
                <strong>{city.itinerary[selectedPhaseId].title}</strong>
                <p>{city.itinerary[selectedPhaseId].note}</p>
              </div>
            </div>
          </div>
        </section>

        <section className="agent section" id="agent">
          <div className="section-heading">
            <p className="eyebrow">Agent board</p>
            <h2>Prototype the AI layer before the backend exists</h2>
          </div>

          <div className="split-grid">
            <form className="column-panel controls" onSubmit={(event) => event.preventDefault()}>
              <label>
                <span>Goal</span>
                <div className="option-row">
                  {goals.map((goal) => (
                    <button
                      key={goal.id}
                      className={goal.id === selectedGoalId ? "pill is-active" : "pill"}
                      onClick={() => setSelectedGoalId(goal.id)}
                      type="button"
                    >
                      {goal.label}
                    </button>
                  ))}
                </div>
              </label>

              <label>
                <span>Language</span>
                <div className="option-row">
                  {languages.map((language) => (
                    <button
                      key={language.id}
                      className={
                        language.id === selectedLanguageId ? "pill is-active" : "pill"
                      }
                      onClick={() => setSelectedLanguageId(language.id)}
                      type="button"
                    >
                      {language.label}
                    </button>
                  ))}
                </div>
              </label>

              <label>
                <span>Matchday phase</span>
                <div className="option-row">
                  {phases.map((phase) => (
                    <button
                      key={phase.id}
                      className={phase.id === selectedPhaseId ? "pill is-active" : "pill"}
                      onClick={() => setSelectedPhaseId(phase.id)}
                      type="button"
                    >
                      {phase.label}
                    </button>
                  ))}
                </div>
              </label>

              <label>
                <span>Filter live plays</span>
                <input
                  className="search-input"
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="hydration, shuttle, meetup..."
                  type="search"
                  value={search}
                />
              </label>
            </form>

            <div className="column-panel assistant-response">
              <p className="panel-kicker">{assistant.eyebrow}</p>
              <h3>{assistant.title}</h3>
              <p>{assistant.summary}</p>
              <ul className="response-list">
                {assistant.bullets.map((bullet) => (
                  <li key={bullet}>{bullet}</li>
                ))}
              </ul>

              <div className="phrase-board">
                {city.phrases.map((phrase) => (
                  <article key={`${phrase.language}-${phrase.native}`}>
                    <span>{phrase.language}</span>
                    <strong>{phrase.native}</strong>
                    <p>{phrase.english}</p>
                  </article>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section className="routes section" id="routes">
          <div className="section-heading">
            <p className="eyebrow">Matchday plays</p>
            <h2>What the app should do in the live moment</h2>
          </div>
          <div className="activation-grid">
            {filteredActivations.map((activation) => (
              <article key={activation.name} className="activation">
                <div>
                  <p className="activation-tag">{activation.category}</p>
                  <h3>{activation.name}</h3>
                </div>
                <p>{activation.description}</p>
                <dl>
                  <div>
                    <dt>Revenue</dt>
                    <dd>{activation.monetization}</dd>
                  </div>
                  <div>
                    <dt>Audience</dt>
                    <dd>{activation.audience}</dd>
                  </div>
                </dl>
              </article>
            ))}
            {filteredActivations.length === 0 ? (
              <article className="activation activation-empty">
                <h3>No activations match that filter.</h3>
                <p>Clear the search or switch phase to expose more plays.</p>
              </article>
            ) : null}
          </div>
        </section>

        <section className="commerce section" id="commerce">
          <div className="section-heading">
            <p className="eyebrow">Commerce engine</p>
            <h2>Monetize only after the fan trusts the flow</h2>
          </div>
          <div className="commerce-list">
            {city.commerce.map((lane) => (
              <article key={lane.label}>
                <p>{lane.revenue}</p>
                <h3>{lane.label}</h3>
                <span>{lane.detail}</span>
              </article>
            ))}
          </div>
        </section>

        <section className="section launch-strip">
          <div>
            <p className="eyebrow">Draft status</p>
            <h2>Frontend-first, mocked intelligence, integration-ready.</h2>
          </div>
          <p>
            The current build proves the product language, city logic, and monetization
            hierarchy. Next pass can wire real translation, payments, and city ops feeds.
          </p>
        </section>
      </main>
    </div>
  );
}
