export type CityId = "kc" | "atl";
export type GoalId = "arrival" | "translate" | "route" | "spend";
export type PhaseId = "morning" | "pregame" | "postgame";
export type LanguageId = "spanish" | "portuguese" | "french";

export type Phrase = {
  language: LanguageId;
  native: string;
  english: string;
};

export type Activation = {
  name: string;
  category: string;
  phase: PhaseId;
  description: string;
  monetization: string;
  audience: string;
};

export type Zone = {
  name: string;
  mood: string;
  distance: string;
  bestFor: string;
};

export type CommerceLane = {
  label: string;
  revenue: string;
  detail: string;
};

export type CityData = {
  id: CityId;
  name: string;
  shortName: string;
  stageLabel: string;
  venueLabel: string;
  heroLabel: string;
  heroTitle: string;
  heroCopy: string;
  atmosphere: string;
  stats: Array<{ label: string; value: string }>;
  itinerary: Record<PhaseId, { title: string; note: string }>;
  zones: Zone[];
  phrases: Phrase[];
  activations: Activation[];
  commerce: CommerceLane[];
  sponsors: string[];
};

export const phases: Array<{ id: PhaseId; label: string }> = [
  { id: "morning", label: "Morning" },
  { id: "pregame", label: "Pre-match" },
  { id: "postgame", label: "Post-match" },
];

export const goals: Array<{ id: GoalId; label: string; hint: string }> = [
  { id: "arrival", label: "Land smoothly", hint: "transport, basecamp, timing" },
  { id: "translate", label: "Translate fast", hint: "phrases, menus, queue help" },
  { id: "route", label: "Move smarter", hint: "fan zones, meetup, exit flow" },
  { id: "spend", label: "Unlock revenue", hint: "passes, merch, sponsor lanes" },
];

export const languages: Array<{ id: LanguageId; label: string }> = [
  { id: "spanish", label: "Spanish" },
  { id: "portuguese", label: "Portuguese" },
  { id: "french", label: "French" },
];

export const cities: Record<CityId, CityData> = {
  kc: {
    id: "kc",
    name: "Kansas City",
    shortName: "KC",
    stageLabel: "Pilot city",
    venueLabel: "Arrowhead host corridor",
    heroLabel: "KC first, chaos reduced, commerce routed.",
    heroTitle: "FanFlow '26 turns Kansas City into a guided matchday runway.",
    heroCopy:
      "This first draft combines translation, routing, meetup coordination, and impulse-ready commerce so arriving fans stop guessing and start moving.",
    atmosphere:
      "Built for tailgate gravity, long ingress lines, and high-emotion purchases before and after kickoff.",
    stats: [
      { label: "Priority lanes", value: "04" },
      { label: "Queue monetizers", value: "03" },
      { label: "Pilot zones", value: "06" },
    ],
    itinerary: {
      morning: {
        title: "Basecamp and arrival lock",
        note: "Push hotel-to-venue timing, weather-aware walking guidance, and hydration checkpoints before the city surges.",
      },
      pregame: {
        title: "Queue control and translation assist",
        note: "Trigger quick-phrases, merch drops, and premium routing when fans are waiting, separated, or confused.",
      },
      postgame: {
        title: "Exit dispersion and spend recapture",
        note: "Guide fans toward meetup bars, shuttle alternatives, and late merch printing while emotion is still hot.",
      },
    },
    zones: [
      {
        name: "Arrowhead corridor",
        mood: "high-friction arrival",
        distance: "0-1 mi",
        bestFor: "queue commerce, hydration passes, crowd language support",
      },
      {
        name: "Crossroads basecamp",
        mood: "creative spillover",
        distance: "15 min ride",
        bestFor: "watch parties, merch pickups, sponsor activations",
      },
      {
        name: "Power & Light transfer zone",
        mood: "nightlife handoff",
        distance: "downtown core",
        bestFor: "meetups, postgame routing, premium fan bundles",
      },
    ],
    phrases: [
      {
        language: "spanish",
        native: "¿Dónde está la fila correcta para entrar?",
        english: "Where is the correct line to get in?",
      },
      {
        language: "portuguese",
        native: "Quanto tempo até o próximo transporte?",
        english: "How long until the next shuttle?",
      },
      {
        language: "french",
        native: "Pouvez-vous m'aider à retrouver mon groupe ?",
        english: "Can you help me find my group?",
      },
    ],
    activations: [
      {
        name: "Queue-side hydration pass",
        category: "Commerce",
        phase: "pregame",
        description: "Sell prepaid cold-water pickups with multilingual redemption instructions.",
        monetization: "high-margin pass with sponsor support",
        audience: "fans stuck in security or concession lines",
      },
      {
        name: "Portable merch print sprint",
        category: "Merch",
        phase: "postgame",
        description: "Print result-reactive shirts and scarves within minutes of the final whistle.",
        monetization: "on-demand apparel without heavy inventory",
        audience: "emotion-led buyers leaving the venue",
      },
      {
        name: "Meet-up pin relay",
        category: "Utility",
        phase: "pregame",
        description: "Give separated groups a translated meetup pin with landmark-based directions.",
        monetization: "premium private group rooms and venue sponsorships",
        audience: "travel groups and multilingual families",
      },
      {
        name: "Walking heat reality mode",
        category: "Routing",
        phase: "morning",
        description: "Show real walking time, heat load, and fallback transport before fans commit.",
        monetization: "affiliate rides and premium route packs",
        audience: "out-of-town visitors leaving hotels late",
      },
    ],
    commerce: [
      {
        label: "Hydration pass",
        revenue: "$12-18 / fan",
        detail: "Prepaid pickups with sponsor branding and zero-friction scanning.",
      },
      {
        label: "Merch flash drops",
        revenue: "$28-65 / order",
        detail: "Emotion-triggered printing tied to match outcomes and city pride.",
      },
      {
        label: "Priority routing",
        revenue: "$6-14 / route",
        detail: "Faster ingress and exit bundles for groups who value certainty.",
      },
    ],
    sponsors: ["Beverage brands", "Transit partners", "Local bars", "Telco roaming offers"],
  },
  atl: {
    id: "atl",
    name: "Atlanta",
    shortName: "ATL",
    stageLabel: "Amplifier city",
    venueLabel: "Downtown + rail pulse",
    heroLabel: "ATL scales the operating system once KC proves the moves.",
    heroTitle: "Atlanta becomes the expansion lane for FanFlow's fastest plays.",
    heroCopy:
      "The ATL version leans into density, nightlife, transit interchanges, and sponsor-friendly activations that can scale once Kansas City validates the core loops.",
    atmosphere:
      "Built for downtown flow, layered hospitality, and higher-volume activation windows.",
    stats: [
      { label: "Expansion lanes", value: "05" },
      { label: "Transit pivots", value: "04" },
      { label: "Sponsor zones", value: "08" },
    ],
    itinerary: {
      morning: {
        title: "Station-ready arrival windows",
        note: "Surface rail timing, luggage storage, and multilingual venue prep before downtown compresses.",
      },
      pregame: {
        title: "Transit confidence and cultural discovery",
        note: "Route fans through partner bars, fan zones, and commerce checkpoints without losing the feeling of momentum.",
      },
      postgame: {
        title: "Nightlife capture and city extension",
        note: "Convert post-match energy into guided bar flows, merch bundles, and sponsor nightlife trails.",
      },
    },
    zones: [
      {
        name: "Stadium district",
        mood: "dense, event-led",
        distance: "walkable core",
        bestFor: "shuttle intelligence, scan-to-order, line compression",
      },
      {
        name: "Midtown social loop",
        mood: "after-dark spillover",
        distance: "short rail hop",
        bestFor: "meetup recovery, nightlife bundles, fan-hosted events",
      },
      {
        name: "Airport arrival belt",
        mood: "high turnover travel",
        distance: "entry corridor",
        bestFor: "luggage storage, SIM deals, guided onboarding",
      },
    ],
    phrases: [
      {
        language: "spanish",
        native: "¿Cuál es la forma más rápida de volver al centro?",
        english: "What is the fastest way back downtown?",
      },
      {
        language: "portuguese",
        native: "Onde fica o ponto de encontro mais próximo?",
        english: "Where is the nearest meetup point?",
      },
      {
        language: "french",
        native: "Je cherche un lieu sûr pour attendre mon groupe.",
        english: "I need a safe place to wait for my group.",
      },
    ],
    activations: [
      {
        name: "Rail-smart exit bundles",
        category: "Routing",
        phase: "postgame",
        description: "Blend transit timing, sponsor promos, and nightlife routing into one guided exit flow.",
        monetization: "paid convenience plus partner kickbacks",
        audience: "fans leaving downtown after the match",
      },
      {
        name: "Airport-to-basecamp onboarding",
        category: "Utility",
        phase: "morning",
        description: "Deliver a guided landing sequence for fans who hit the city and a match in the same day.",
        monetization: "affiliate transport, SIM packages, luggage storage",
        audience: "international travelers on compressed itineraries",
      },
      {
        name: "Culture pod passport",
        category: "Experience",
        phase: "pregame",
        description: "Route supporters through branded mini-cultural zones with rewards for each stop.",
        monetization: "sponsor-backed redemptions and paid upgrades",
        audience: "groups exploring before kickoff",
      },
      {
        name: "Night shift merch route",
        category: "Merch",
        phase: "postgame",
        description: "Push timed merch offers tied to bars, music venues, and late-night fan traffic.",
        monetization: "late conversion on scarce items",
        audience: "fans extending the night after the final whistle",
      },
    ],
    commerce: [
      {
        label: "Transit confidence packs",
        revenue: "$8-16 / rider",
        detail: "Premium route confidence with promo bundles and live fallback plans.",
      },
      {
        label: "Nightlife bundles",
        revenue: "$20-40 / head",
        detail: "Partner drink credits, queue bypass, and meetup recovery messaging.",
      },
      {
        label: "Airport onboarding",
        revenue: "$15-35 / trip",
        detail: "Luggage, connectivity, and guided first-stop recommendations bundled together.",
      },
    ],
    sponsors: ["MARTA-adjacent partners", "Hospitality groups", "Beverage brands", "Mobile carriers"],
  },
};
