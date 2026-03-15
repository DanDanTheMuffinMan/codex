# Perfect Mirror sync bootstrap

This guide mirrors a Mac Codex workspace onto another machine using the runtime versions you provided.

## 1) Environment parity script (`setup.sh`)

Use `scripts/perfect-mirror-setup.sh`:

```bash
./scripts/perfect-mirror-setup.sh
```

It validates these versions and prints exact `rustup`/`mise` remediation commands when mismatched:

- Rust `1.89.0`
- Node `20.19.6`
- Python `3.12.12`

## 2) Codex CLI linkage sequence (`codex-cli-linkage.sh`)

```bash
# Install Codex CLI globally with npm.
npm install -g @openai/codex

# Authenticate (follow browser/device prompts).
codex login

# Verify identity is active.
codex whoami

# From your mirrored repo root, initialize/link to cloud context.
codex init
```

If npm global installs are not desired, use `npx @openai/codex@latest` for one-off usage.

## 3) High-performance `config.toml`

Copy to `~/.codex/config.toml` and adjust paths/models as needed.

```toml
model = "gpt-5-codex"
model_reasoning_effort = "high"

approval_policy = "on-request"
sandbox_mode = "workspace-write"

# Improve responsiveness for large repos.
notify = ["bash", "-lc", "printf '\\a'"]
project_doc_max_bytes = 65536

# Keep local project indexing and thread continuity stable.
[features]
file_search = true

[projects."/ABSOLUTE/PATH/TO/YOUR/REPO"]
trust_level = "trusted"

[profiles.mirror]
model = "gpt-5-codex"
approval_policy = "on-request"
sandbox_mode = "workspace-write"
```

## 4) Template `AGENTS.md`

Drop this into your mirrored repository root and customize the rules:

```markdown
# AGENTS.md

## Purpose
Keep this machine in sync with the primary Mac Codex workspace.

## Working agreement
- Prefer small, reviewable commits.
- Run formatter and tests before commit.
- Keep documentation updated for any behavior/API changes.
- Record exact verification commands in final summaries.

## Sync policy
- Work only on shared git branches.
- Pull latest upstream before starting a task.
- Push branch updates after each verified checkpoint.
```

## 5) One-command dependency alignment

```bash
bash -lc '
set -euo pipefail
pnpm install
(
  cd codex-rs
  cargo fetch --locked
)
if [ -f requirements.txt ]; then
  python3 -m pip install -r requirements.txt
else
  echo "No requirements.txt found at repo root; skipping pip install"
fi
'
```

## 6) Verification command (memory + skills parity)

Run this on both machines and compare outputs:

```bash
bash -lc '
echo "=== Codex identity ==="
codex whoami || true
echo
echo "=== Codex home ==="
echo "${CODEX_HOME:-$HOME/.codex}"
echo
echo "=== Installed skills ==="
find "${CODEX_HOME:-$HOME/.codex}/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort || true
echo
echo "=== Active AGENTS files in repo path ==="
find . -name "AGENTS.md" -o -name "AGENTS.override.md" 2>/dev/null | sort || true
'
```

Matching identity, available skills, and AGENTS stack gives you practical parity with the Mac setup.
