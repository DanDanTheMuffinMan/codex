# FanFlow '26 Web Draft

This folder contains a standalone first draft of the FIFA 2026 fan app concept focused on two host-city modes:

- Kansas City as the pilot city
- Atlanta as the expansion lane

## What this draft proves

- The product voice and visual direction
- City-specific matchday logic
- A mocked AI operations panel for translation, routing, and spend guidance
- Commerce surfaces tied to real fan friction: hydration, routing, merch, meetup recovery

## What is mocked

- No live translation API
- No payments, user accounts, or database
- No map SDK, transit feed, or venue telemetry

## Next integrations

- Google Drive for structured research sync and source-of-truth docs
- Gmail for sponsor and ops inbox summarization
- Stripe for hydration passes, merch deposits, and premium routing
- Cloudflare or Vercel for edge-hosted APIs and fast preview deploys
- Figma / Canva for design-system capture and sponsor-facing collateral
- Native shells later via iOS / Android once the web flow is validated

## Run locally

```bash
cd /Users/adamterra/Documents/GitHub/codex/unova/fanflow26-web
pnpm install --ignore-workspace
pnpm dev
```

Then open the local Vite URL printed in the terminal.
