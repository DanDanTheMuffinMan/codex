export type FailureMode = {
  id: string;
  label: string;
  description: string;
  rescueCue: string;
  buildFix: string;
};

export type SectionPreset = {
  id: string;
  label: string;
  lane: string;
  difficulty: string;
  length: string;
  focus: string;
  intensity: string;
  cues: string[];
  designPrompt: string;
  coachHint: string;
};

export type MoodOption = {
  id: string;
  label: string;
  flavor: string;
  mantra: string;
};

export type SpeedOption = {
  id: string;
  label: string;
  feel: string;
  mantra: string;
};

export type GimmickOption = {
  id: string;
  label: string;
  flavor: string;
  fakeOut: string;
  payoff: string;
};

export type PaletteOption = {
  id: string;
  label: string;
  colors: string[];
  texture: string;
};

export const failureModes: FailureMode[] = [
  {
    id: "late-tap",
    label: "Late tap",
    description:
      "The input lands after the obstacle has already closed the window.",
    rescueCue: "Call the jump one beat earlier and breathe before the orb.",
    buildFix:
      "Create a cleaner lead-in platform so the rhythm reads instantly.",
  },
  {
    id: "early-tap",
    label: "Early tap",
    description: "The jump starts before the visual cue finishes arriving.",
    rescueCue: "Wait for the shape to lock, then tap on the downbeat.",
    buildFix:
      "Add one calm setup block before the hazard to slow the eye down.",
  },
  {
    id: "double-tap",
    label: "Panic double tap",
    description: "A second tap sneaks in and throws the rhythm off the lane.",
    rescueCue: "Reduce the loop to one clean input and reset after each try.",
    buildFix:
      "Separate chained orbs so each action reads like its own decision.",
  },
  {
    id: "release",
    label: "Bad hold release",
    description:
      "The hold is right, but the release timing collapses the exit.",
    rescueCue: "Count the hold out loud and let go at the color change.",
    buildFix:
      "Use a stronger light/dark contrast where the release should happen.",
  },
  {
    id: "portal-shock",
    label: "Portal shock",
    description: "Speed or gravity changes are scrambling the section reset.",
    rescueCue:
      "Practice only the portal entry three times before running the rest.",
    buildFix:
      "Echo the upcoming speed shift with color, arrows, or empty space.",
  },
];

export const sectionPresets: SectionPreset[] = [
  {
    id: "cube-lock",
    label: "Cube rhythm gate",
    lane: "Grounded opener",
    difficulty: "Normal to Harder",
    length: "6 inputs",
    focus: "Stable sightlines and one rhythm you can chant.",
    intensity: "Measured",
    cues: ["Set feet", "Tap", "Tap", "Hold", "Release", "Land"],
    designPrompt:
      "A calm opener with obvious contrast that teaches the player the section before it twists.",
    coachHint: "Use a short mantra and keep the eyes low on the lane.",
  },
  {
    id: "orb-climb",
    label: "Orb ladder",
    lane: "Air control",
    difficulty: "Harder to Insane",
    length: "7 inputs",
    focus: "Rhythm over reaction. Make every orb feel announced.",
    intensity: "Rising",
    cues: [
      "Float",
      "Hit yellow",
      "Pause",
      "Hit pink",
      "Drop",
      "Recover",
      "Exit",
    ],
    designPrompt:
      "A rising ladder section that feels playful first and dangerous second.",
    coachHint: "Narrate the orb colors, not the panic.",
  },
  {
    id: "wave-slice",
    label: "Wave corridor",
    lane: "Precision burst",
    difficulty: "Insane to Demon-lite",
    length: "8 inputs",
    focus: "Tiny windows with clear visual rails and no clutter.",
    intensity: "Sharp",
    cues: ["Set line", "Up", "Down", "Up", "Micro hold", "Down", "Up", "Exit"],
    designPrompt:
      "A neon corridor that looks dangerous but still teaches the exact safe line.",
    coachHint: "Reduce the section until the line feels like one gesture.",
  },
  {
    id: "mirror-fakeout",
    label: "Mirror fake-out",
    lane: "Mind-game pivot",
    difficulty: "Harder to Insane",
    length: "5 inputs",
    focus: "Fake tension, then a clear release into space.",
    intensity: "Sneaky",
    cues: ["Trust center", "Wait", "Tap", "Flip", "Go"],
    designPrompt:
      "A mischievous section that teases confusion but rewards commitment.",
    coachHint: "Build a single anchor point and return to it every run.",
  },
];

export const moods: MoodOption[] = [
  {
    id: "solar",
    label: "Solar forge",
    flavor: "glowing metal, warm edges, release after pressure",
    mantra: "Heat up slowly, then open the lane wide",
  },
  {
    id: "glacier",
    label: "Glacier pulse",
    flavor: "cool air, glass light, precise pressure",
    mantra: "Keep the path crisp and let the blue do the warning",
  },
  {
    id: "night-market",
    label: "Night market",
    flavor: "lively signs, color pops, rhythm through motion",
    mantra: "Make every fake-out feel playful before it bites",
  },
  {
    id: "storm-signal",
    label: "Storm signal",
    flavor: "dark weather, electric seams, sudden relief",
    mantra: "Let the danger hum before the drop arrives",
  },
];

export const speeds: SpeedOption[] = [
  {
    id: "steady",
    label: "Steady",
    feel: "calm and chantable",
    mantra: "Teach first, flex second",
  },
  {
    id: "snap",
    label: "Snap",
    feel: "quick but readable",
    mantra: "Short loops, hard punctuation",
  },
  {
    id: "surge",
    label: "Surge",
    feel: "accelerating with intent",
    mantra: "Every speed-up needs a visual runway",
  },
  {
    id: "glide",
    label: "Glide",
    feel: "floaty, elegant, and deceptive",
    mantra: "The section should breathe even while it tricks",
  },
];

export const gimmicks: GimmickOption[] = [
  {
    id: "gravity",
    label: "Gravity flip",
    flavor: "ceiling-floor inversion",
    fakeOut: "hint at chaos before the flip actually matters",
    payoff: "reward the player with a clean landing window after the reversal",
  },
  {
    id: "pulse-orbs",
    label: "Pulse orbs",
    flavor: "color-coded rhythm hits",
    fakeOut: "use one silent orb to teach the player not to spam",
    payoff: "finish with a satisfying color chain",
  },
  {
    id: "mirror",
    label: "Mirror feint",
    flavor: "visual misdirection and center-line trust",
    fakeOut: "push the eye off center right before the true safe path appears",
    payoff: "resolve into a wide, obvious escape lane",
  },
  {
    id: "teleport",
    label: "Teleport stitch",
    flavor: "hard cuts with preserved rhythm",
    fakeOut: "blink the player into a tighter lane without changing the beat",
    payoff: "snap into a cleaner space that feels earned",
  },
];

export const palettes: PaletteOption[] = [
  {
    id: "ember-cyan",
    label: "Ember / Cyan",
    colors: ["#ff824d", "#ffc857", "#75f5ff", "#0d1320"],
    texture: "warm glow against cool edges",
  },
  {
    id: "mint-laser",
    label: "Mint / Laser",
    colors: ["#b8ff5f", "#6fffe9", "#20354f", "#0a0f1a"],
    texture: "acid light with disciplined darkness",
  },
  {
    id: "violet-steel",
    label: "Violet / Steel",
    colors: ["#c6a0ff", "#6e7bf2", "#2b3552", "#111521"],
    texture: "soft mystic edges over industrial structure",
  },
  {
    id: "sunset-core",
    label: "Sunset / Core",
    colors: ["#ff9a5a", "#ffdb8a", "#7cf0c4", "#141724"],
    texture: "festival warmth with clear runway contrast",
  },
];
