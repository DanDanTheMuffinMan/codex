#!/usr/bin/env bash
# macOS Codex runtime parity check for perfect mirror setup.
set -euo pipefail

readonly EXPECTED_RUST="1.90.0"
readonly EXPECTED_NODE="22"
readonly EXPECTED_PYTHON="3.12.12"

fail=0

report_exact_check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    printf '✅ %s %s\n' "$name" "$actual"
  else
    printf '❌ %s expected %s but found %s\n' "$name" "$expected" "$actual"
    fail=1
  fi
}

report_major_check() {
  local name="$1" expected_major="$2" actual="$3"
  local actual_major="${actual%%.*}"

  if [[ "$actual" != "missing" && "$actual_major" == "$expected_major" ]]; then
    printf '✅ %s %s (major %s matched)\n' "$name" "$actual" "$expected_major"
  else
    printf '❌ %s expected major %s.x but found %s\n' "$name" "$expected_major" "$actual"
    fail=1
  fi
}

has_tool() { command -v "$1" >/dev/null 2>&1; }

uname_s=$(uname -s || true)
if [[ "$uname_s" != "Darwin" ]]; then
  printf '⚠️ This script is intended for macOS (Darwin); detected %s\n' "$uname_s"
fi

if has_tool rustc; then
  rust_actual=$(rustc -Vv | awk '/^release:/ {print $2}')
else
  rust_actual="missing"
fi

if has_tool node; then
  node_actual=$(node -p 'process.versions.node')
else
  node_actual="missing"
fi

if has_tool python3; then
  python_actual=$(python3 - <<'PY'
import platform
print(platform.python_version())
PY
)
else
  python_actual="missing"
fi

report_exact_check "rustc" "$EXPECTED_RUST" "$rust_actual"
report_major_check "node" "$EXPECTED_NODE" "$node_actual"
report_exact_check "python3" "$EXPECTED_PYTHON" "$python_actual"

if [[ $fail -ne 0 ]]; then
  printf '\nRemediation hints (only shown if the tooling exists):\n'
  if has_tool mise; then
    printf '  mise use -g node@%s rust@%s python@%s\n' "$EXPECTED_NODE" "$EXPECTED_RUST" "$EXPECTED_PYTHON"
  elif has_tool rustup || has_tool nodenv || has_tool pyenv; then
    printf '  Consider using mise or your env manager to pin versions.\n'
  else
    printf '  Install mise (or similar) to manage versions.\n'
  fi
  exit 1
fi

printf '\n✅ Codex runtime parity check passed (macOS expected). Re-run anytime; idempotent check only.\n'