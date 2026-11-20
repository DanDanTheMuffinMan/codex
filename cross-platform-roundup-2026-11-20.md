# Cross-Platform Roundup — 2026-11-20

Previous run: 2026-11-14 (draft PR #13). **Almost nothing has changed since then.**

## Coverage

| Platform                          | Status this run                                                                                                                                                                                   |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude (this agent)               | Checked. Ran OK. No in-session cron jobs. Slack and built-in GitHub tools work. Same connector failures as last week: GitHub plugin (bad auth header), Datadog (proxy 502), Zoom (token rejected), HubSpot/Xero/BigQuery/Box (auth server incompatible). New this week: CockroachDB toolbox (executable missing). About 90 plugins still need sign-in. |
| GitHub `DanDanTheMuffinMan/codex` | Checked. 3 open draft PRs, 0 open issues. Nothing merged since PR #8. PR #13 (last week's roundup) has had no activity.                                                                          |
| Codex Pro (personal)              | **Not reachable.** No connector or API.                                                                                                                                                           |
| Codex Business                    | **Not reachable.**                                                                                                                                                                                |
| ChatGPT Pro (personal)            | **Not reachable.**                                                                                                                                                                                |
| ChatGPT Business                  | **Not reachable.**                                                                                                                                                                                |
| Monica                            | **Not reachable.**                                                                                                                                                                                |
| Grok                              | **Not reachable.**                                                                                                                                                                                |

Activity is minimal. 6 of 8 targets still can't be read, so their status is unknown. That does not mean they are healthy.

## Pending items

| PR  | Title                                                    | Author  | Last update | Age       |
| --- | -------------------------------------------------------- | ------- | ----------- | --------- |
| #13 | Add cross-platform roundup report (2026-11-14)           | you     | 2026-11-14  | 6 days    |
| #12 | Add unova/lyric-decipher: multi-pass lyric transcription | you     | 2026-08-17  | ~3 months |
| #11 | UNOVA cleanup: portable docs/configs, workflow validator | Copilot | 2026-08-16  | ~3 months |

## Cross-platform insights

- **No recommendations from last week were acted on.** The blockers below are the same ones reported on 11-14.
- This routine still can't read Codex, ChatGPT, Monica or Grok. Each weekly run will look the same until one of them writes to a place Claude can read, such as Slack, GitHub or Google Drive.
- Roundup reports are piling up as draft PRs that nobody reviews. That adds to the stale-PR problem instead of fixing it.
- PRs #11 and #12 both touch UNOVA and are still unresolved after about 3 months.

## Individual recommendations

- **Claude:** Fix or remove the GitHub plugin, Datadog, Zoom and CockroachDB connectors. Prune plugins you don't use.
- **GitHub:** Make a decision on #11 and #12: merge, rebase or close each. Close #13 once you've read it (this report replaces it).
- **Codex Pro / Business:** Have Codex post a short weekly summary to Slack or open a GitHub issue. This routine can read either one.
- **ChatGPT Pro / Business:** Send a weekly export or summary to Slack, email or Drive.
- **Monica / Grok:** Decide whether to keep them in this roundup. If you keep them, they need an export path. If not, take them out of the prompt.

## Group recommendations

- Create one hub channel, such as `#ai-roundup`, and put its name in this routine's prompt. The routine can then read updates from it and post the summary there.
- Change where the routine sends its output. Instead of opening a new draft PR every week, have it update a single running file or a Slack canvas.
- Think about running the routine less often, every two weeks or monthly, until more platforms are connected. Right now each weekly run repeats the last one.

## Distribution

- Saved in the repo on branch `claude/amazing-mendel-b34shv`.
- A Slack draft is in your own DM for you to review. Nothing was posted to `#general`, because the routine doesn't name a channel.
- Codex, ChatGPT, Monica and Grok: share this by hand (paste the file).
