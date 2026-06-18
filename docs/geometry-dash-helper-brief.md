# Geometry Dash Helper Brief

## Product thesis

Build a companion that lowers frustration without stealing ownership.

The first version should help a kid get unstuck on hard sections, understand why a section is hard, and turn game excitement into level-building creativity. It should feel like a coach and co-builder first, not an all-powerful cheat engine.

## Primary recommendation

Do not start with full computer control that can beat any part of any level.

Start with a multimodal helper:

- visual first
- hotkey driven
- optional push-to-talk voice
- short, predictable actions

Voice alone is not a good primary interface for a timing game. It is useful for planning, encouragement, and build prompts, but not for frame-precise play.

## Core user jobs

- get past one hard section without rage-spiking
- understand the pattern in plain language
- practice a short segment repeatedly
- capture ideas for new levels fast
- turn vague ideas into a concrete build plan
- keep the experience calm, predictable, and rewarding

## Accessibility stance

Design for low surprise and high clarity:

- one action per screen
- large controls and consistent placement
- optional reduced sound and visual noise
- countdowns before any automation starts
- visible state at all times: idle, listening, recording, replaying, suggesting
- no hidden background control

Do not assume voice is always easier. Make it optional, not required.

## Version 1 scope

### 1. Practice Rescue

Help with one short section at a time:

- mark the start and end of the hard part
- record a few failed attempts
- detect repeated mistakes by timing and position
- explain the section simply: "late tap", "double tap too fast", "jump earlier after the orb"
- offer a looped practice mode with beat counts and tap cues

### 2. Section Autopilot

Keep this narrow and explicit:

- works only on a short marked segment
- requires user confirmation before taking control
- shows a 3-2-1 countdown
- stops immediately on keypress
- logs exactly what it is doing

This is the "cool uncle" move without turning the whole project into a brittle botnet for a platformer.

### 3. Builder Companion

Turn his ideas into level design structure:

- accept prompts by text or voice
- generate a section theme, mood, difficulty, and obstacle sequence
- suggest color palettes and pacing changes
- break a level idea into chunks: intro, fake-out, speed-up, release, finale
- save idea cards so he can revisit them later

## Product decision

If you can only build one thing first, build this:

Practice Rescue + Builder Companion.

That creates value immediately, supports his learning style, and gives him a creative loop. Section Autopilot can be added after the practice loop feels reliable.

## Why not full "beat any part of any level" first

- it is the hardest technical problem
- it is the easiest way to make him dependent on the tool
- it teaches the least
- it is brittle across different level visuals and speeds
- it shifts the emotional reward from "I made this" to "the machine did it"

## Suggested technical shape

Desktop app with three surfaces:

1. Overlay

   - status
   - countdown
   - beat cues
   - simple coaching text

2. Coach panel

   - start/end segment controls
   - replay analysis
   - voice input toggle
   - safety stop

3. Builder notebook
   - idea capture
   - section generator
   - saved concepts

## Implementation path

### Phase 1

- screen capture the game window
- let the user mark a short section
- add hotkeys for record, retry, and cue overlay
- produce simple coaching output from repeated attempts

### Phase 2

- add optional push-to-talk prompts for builder mode
- generate level section ideas from plain-language prompts
- save and reload project ideas

### Phase 3

- add short-segment autopilot
- keep the control boundary explicit and interruptible
- never run hidden full-level automation

## Success criteria

- he gets unstuck faster on one hard section
- he can explain what the section is asking him to do
- he generates at least one build idea he is excited to try
- the tool feels calming, not overwhelming

## My recommendation to Daniel

Be the cool uncle by building the thing that says:

"I can help you through this part, and I can help you make your own wild stuff too."

That is stronger than a pure bot. It meets him where he is and pushes the excitement toward authorship, not just bypass.
