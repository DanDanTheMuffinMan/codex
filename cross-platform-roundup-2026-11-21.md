# Cross-Platform Roundup — 2026-11-21

Previous run: 2026-11-20 (draft PR #14). **New this run: Gmail was checked, and it shows three OpenAI deadlines and an open support case that needs your reply.**

## Act this week

| Due        | Item                                                                                                                                                                                                        |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Nov 24** | ChatGPT Business ("Daniel Shafton's Workspace") renews, billed for 1 Premium seat. Keep or cancel before then.                                                                                              |
| **Nov 24** | OpenAI asks you to review workspace admins (admins will be able to approve join requests and add paid seats).                                                                                               |
| Open now   | OpenAI support case **20448121** (NovaDot-Pro gives no written replies). Support's last reply (Nov 18, unread) says it looks like a general ChatGPT connectivity / websocket issue and asks for next steps. |
| **Dec 11** | Custom GPTs are retiring. Export or migrate any you rely on.                                                                                                                                                |
| Soon       | Two "Update your Base44 connection" emails from OpenAI. Reconnect Base44 in ChatGPT.                                                                                                                        |

## Coverage

| Platform                          | Status this run                                                                                                                                                                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude (this agent)               | Ran OK. No in-session cron jobs. Slack, Gmail and built-in GitHub tools work. Same connector failures as before: GitHub plugin (bad auth header), Datadog (proxy 502), Zoom (token rejected), CockroachDB, HubSpot/Xero/BigQuery/Box. |
| GitHub `DanDanTheMuffinMan/codex` | 4 open draft PRs (#11–#14), 0 issues. Nothing merged since PR #8. The CLA Assistant check **fails** on the roundup branches (PRs #13 and #14).                                                                                        |
| Codex Pro / Business              | No direct access. Indirect: Codex sent a support follow-up for case 20448121 on your behalf (Nov 18).                                                                                                                                 |
| ChatGPT Pro (personal)            | No direct access. Via email: support case 20448121 is open; NovaDot-Pro written replies are broken across web, macOS, iOS and iMessage.                                                                                               |
| ChatGPT Business                  | No direct access. Via email: renewal and admin review both due Nov 24.                                                                                                                                                                |
| Monica                            | Not reachable. No email activity found.                                                                                                                                                                                               |
| Grok                              | Not reachable. Only marketing email (Voice, "what's happening now"). Nothing pending.                                                                                                                                                 |

## Cross-platform insights

- **Email is a working back door.** OpenAI, Grok and GitHub all send account notices to Gmail, so this routine can now see billing dates, support cases and CI failures it couldn't see before.
- Codex is already acting for you (support follow-up). That makes the NovaDot-Pro issue a Codex + ChatGPT dependency: if ChatGPT connectivity is broken, Codex workflows that rely on it may be affected too.
- The roundup PRs keep failing the CLA check and nobody reviews them. They add noise, not value.
- PRs #11 and #12 (UNOVA) are still untouched after about 3 months.

## Individual recommendations

- **ChatGPT Business:** Decide on the Nov 24 renewal. If you keep it, review admins the same day.
- **ChatGPT Pro:** Reply to case 20448121 with the steps support asked for. Back up any Custom GPTs before Dec 11. Reconnect Base44.
- **Codex:** Keep using it for support follow-ups, but have it post a short summary to Slack or a GitHub issue so this routine can track it.
- **Claude:** Fix or remove the broken connectors listed above.
- **GitHub:** Close #13 and #14 (this report replaces them). Merge, rebase or close #11 and #12. Fix the CLA allowlist for Claude's commits, or exclude `claude/*` branches from the check.
- **Monica / Grok:** Nothing pending. Decide whether to keep them in this routine.

## Group recommendations

- Add a Gmail label or filter for OpenAI / xAI / Monica account mail. This routine can then read it in one query.
- Use one Slack hub channel (for example `#ai-roundup`) and name it in the routine's prompt.
- Replace weekly draft PRs with one running file or a Slack canvas.

## Distribution

- Saved in the repo on branch `claude/amazing-mendel-5l4mlw`.
- Slack: draft in your own DM for review. Nothing posted to a channel, because the routine doesn't name one.
- Codex, ChatGPT, Monica, Grok: share by hand.
