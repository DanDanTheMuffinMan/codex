# FanFlow '26 First Draft

## Product thesis

FanFlow '26 is a World Cup fan companion for Kansas City and Atlanta that solves high-stress matchday moments first, then monetizes the moments after trust is earned.

Core user jobs:

- understand where to go
- translate fast
- regroup with friends
- avoid bad transit decisions
- buy the right thing at the right emotional moment

## Version 1 scope

- mobile-first web app
- city switch between Kansas City and Atlanta
- mocked AI operator panel
- phase-based matchday planning: morning, pre-match, post-match
- commerce surfaces: hydration, merch, routing, nightlife bundles

## Source grounding used in this draft

- local FIFA notes and thread exports in Downloads
- partnership agreement covering app, brands, products, and related ventures
- Google Drive folder `FIFA World Cup Project: ATL + KC 2026`
- Gmail context showing current Kansas City World Cup activity

## Suggested system path

1. Keep the first production release as a fast web app.
2. Add server endpoints for translation, itinerary generation, and sponsor offers.
3. Wire payments only after the core route + translation loop is proven.
4. Add native wrappers later if repeated usage justifies push notifications, wallet, or offline storage.

## Connector path

- `Google Drive`: ingest research docs, budgets, permits, and meeting notes into an internal knowledge layer.
- `Gmail`: summarize inbound sponsor, permit, and city-readiness messages into tasks.
- `Stripe`: hydrate the commerce layer with passes, deposits, and merch checkout.
- `Cloudflare`: good target for edge APIs, caches, and geo-aware request routing.
- `Figma`: mirror the current UI into a design file once the product structure settles.
- `Canva`: generate sponsor-facing and activation-ready collateral after the product language is locked.

## Immediate next build steps

1. Add real data models for city events, meetup pins, and sponsor offers.
2. Introduce an API boundary for translation and itinerary generation.
3. Add a lightweight auth model for saved groups and pinned routes.
4. Deploy a preview and test the mobile flow in a browser and emulator.
