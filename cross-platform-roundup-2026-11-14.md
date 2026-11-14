# Cross-Platform Roundup — 2026-11-14

## Coverage

| Platform                          | Status this run                                                                                                                                                                                                                                                                                                  |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude (this agent)               | Checked. Ran OK. No scheduled cron jobs in-session. Slack connected. Some MCP servers fail to connect: GitHub plugin (bad auth header; the built-in GitHub tools still work), Datadog, Zoom (token rejected), HubSpot/Xero/BigQuery/PagerDuty (auth server incompatibility). About 90 others still need sign-in. |
| GitHub `DanDanTheMuffinMan/codex` | Checked. 2 open draft PRs. Both are stale (no update since mid-Aug, about 3 months). Last merge on main was PR #8 (CLA allowlist fixes).                                                                                                                                                                         |
| Codex Pro (personal)              | **Not reachable.** No connector or API available to this agent.                                                                                                                                                                                                                                                  |
| Codex Business                    | **Not reachable.** No connector.                                                                                                                                                                                                                                                                                 |
| ChatGPT Pro (personal)            | **Not reachable.** No connector.                                                                                                                                                                                                                                                                                 |
| ChatGPT Business                  | **Not reachable.** No connector.                                                                                                                                                                                                                                                                                 |
| Monica                            | **Not reachable.** No connector.                                                                                                                                                                                                                                                                                 |
| Grok                              | **Not reachable.** No connector.                                                                                                                                                                                                                                                                                 |

Activity is minimal. Only Claude and GitHub could be checked. The other six platforms have no integration this agent can query, so their status is unknown. It is not "healthy".

## Pending items

- **PR #12** (draft, yours): "Add unova/lyric-decipher: multi-pass lyric transcription pack". Last updated 2026-08-17.
- **PR #11** (draft, Copilot agent): "UNOVA cleanup: portable docs/configs, remove draft surfaces, add workflow validator". Last updated 2026-08-16.

## Cross-platform insights

- This roundup can't see most of your setup. 6 of the 8 targets have no read path, so the summary depends on whatever you export by hand.
- Several coding agents work in the same repo (Claude, Copilot, Codex). PRs #11 and #12 both touch the UNOVA area and have sat for about 3 months. They may conflict, so decide on them together.
- The connector list has many plugins installed that never finished sign-in. That adds noise to every agent session.

## Individual recommendations

- **Claude:** Fix or remove the failing GitHub plugin, Datadog and Zoom connectors. Prune unused plugins.
- **GitHub:** Triage PR #11 and #12. Merge them, rebase them, or close them.
- **Codex Pro / Business:** Export recent task history, or check whether Codex can post to Slack or GitHub. That would give this roundup something to read.
- **ChatGPT Pro / Business:** Turn on a shared export, such as a weekly summary sent to Slack or email. Until then this roundup can't report on them.
- **Monica / Grok:** Decide whether these are still worth including. If they are, set up an export path. If not, drop them from the roundup.

## Group recommendations

- Pick one shared hub, such as a Slack channel (e.g. `#ai-roundup`), where every platform posts its updates. This routine can then read and summarize that channel.
- Name that channel in this routine's prompt so it can post there directly. Right now it only saves a draft.
- Make one person responsible for each repo's agent-authored PRs, so drafts don't go stale.

## Distribution

- Saved to the repo working copy (this file).
- A Slack draft was created in your own DM so you can review it. Nothing was posted to a channel, because the routine doesn't name one.
- Codex, ChatGPT, Monica and Grok need to be shared by hand. Paste this file into each one.
