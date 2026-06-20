# Perfect Mirror sync bootstrap

Mirror one macOS Codex workspace to another without inventing repo-local commands that do not exist. This guide uses the runtime targets the repository actually declares and gives you a repeatable way to compare Codex login, config, skills, and `AGENTS.md` state between machines.

## 1) Run the runtime parity script

Use `scripts/perfect-mirror-setup.sh` from the repository root:

```bash
./scripts/perfect-mirror-setup.sh | tee parity.log
```

The script is safe to re-run and exits non-zero on mismatch. It derives its targets from repo metadata wherever possible:

- Rust exact version from `codex-rs/rust-toolchain.toml`
- Node minimum major from `package.json` `engines.node`
- Python exact version from `PERFECT_MIRROR_PYTHON_VERSION`, repo `.python-version`, or fallback `3.12.12`

Good output ends with `PASS  Codex runtime parity check passed.`. On mismatch, the script prints concrete remediation commands for `rustup`, `nvm`, `pyenv`, and `mise` when available.

## 2) Install Codex CLI and verify account access

```bash
# Install the CLI globally.
npm install -g @openai/codex

# Authenticate with ChatGPT/OpenAI.
codex login

# Verify the stored login state.
codex login status

# Confirm cloud access and visible environments/tasks.
codex cloud
```

There is no separate `codex whoami` or `codex init` command in this CLI. Running Codex from the repository root is enough for it to pick up local config, project trust, and `AGENTS.md` files.

If you prefer one-off usage instead of a global install, use `npx @openai/codex@latest login` and `npx @openai/codex@latest login status`.

## 3) High-performance `config.toml` template

Copy this to `~/.codex/config.toml` and adjust paths or model choices as needed:

```toml
model = "gpt-5-codex"
review_model = "gpt-5-codex"
approval_policy = "on-request"
sandbox_mode = "workspace-write"
project_doc_max_bytes = 65536
notify = ["bash", "-lc", "printf '\\a'"]

[features]
unified_exec = true
streamable_shell = true
apply_patch_freeform = true
view_image_tool = true

[tui]
notifications = ["agent-turn-complete", "approval-requested"]

[sandbox_workspace_write]
network_access = false

[profiles.mirror]
model = "gpt-5-codex"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[projects."/ABSOLUTE/PATH/TO/codex"]
trust_level = "trusted"
```

## 4) `AGENTS.md` template for a mirrored repo

Drop this into the mirrored repository root and customize it for your team:

```markdown
# AGENTS.md

## Purpose

Keep this mirror workspace behaviorally aligned with the primary Codex machine.

## Working rules

- Prefer small, reviewable diffs.
- Run targeted verification before final summaries.
- Use only documented Codex CLI subcommands.
- Record the exact commands used for validation.

## Sync rules

- Pull before starting a task.
- Push after each verified checkpoint.
- Keep `~/.codex/config.toml`, global `AGENTS.md`, and repo `AGENTS.md` files in sync.
```

## 5) One-command dependency alignment

```bash
bash -lc '
set -euo pipefail
pnpm install --frozen-lockfile
cargo fetch --manifest-path codex-rs/Cargo.toml --locked
'
```

## 6) Verification command for login, skills, and `AGENTS.md` parity

Run this on both machines and compare the output:

```bash
bash -lc '
set -euo pipefail
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

echo "=== Codex login ==="
codex login status || true

echo
echo "=== Config digest ==="
shasum -a 256 "$CODEX_HOME/config.toml" 2>/dev/null || echo "config.toml missing"

echo
echo "=== Global AGENTS ==="
for path in "$CODEX_HOME/AGENTS.override.md" "$CODEX_HOME/AGENTS.md"; do
  [ -f "$path" ] && echo "$path"
done

echo
echo "=== Installed skills ==="
find "$CODEX_HOME/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort || true

echo
echo "=== Repo AGENTS stack ==="
find . \( -name "AGENTS.md" -o -name "AGENTS.override.md" \) 2>/dev/null | sort || true
'
```

For a deterministic comparison, save the output on both machines and diff the results:

```bash
bash -lc '
set -euo pipefail
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
codex login status || true
shasum -a 256 "$CODEX_HOME/config.toml" 2>/dev/null || echo "config.toml missing"
find "$CODEX_HOME/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort || true
find . \( -name "AGENTS.md" -o -name "AGENTS.override.md" \) 2>/dev/null | sort || true
' > mirror-a.txt
diff -u mirror-a.txt mirror-b.txt
```
