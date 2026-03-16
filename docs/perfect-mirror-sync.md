# Perfect Mirror sync bootstrap
This guide mirrors a Mac Codex workspace onto another machine using the runtime versions you provided.

## 1) Environment parity script (`perfect-mirror-setup.sh`)
Use `scripts/perfect-mirror-setup.sh`:

```bash
./scripts/perfect-mirror-setup.sh > parity.log
```

It validates these versions, exits non-zero on mismatch, and prints remediation hints when mismatched:
- Rust `1.89.0`
- Node `20.19.6`
- Python `3.12.12`

**Idempotency:** safe to re-run; `parity.log` stays deterministic for diffing between machines.
**Security:** avoid `curl ... | bash`; verify installers via pinned hashes/versions.

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
