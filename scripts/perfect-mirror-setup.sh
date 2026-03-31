#!/usr/bin/env bash
# macOS Codex runtime parity check for perfect mirror setup.
set -euo pipefail

readonly ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
)"
readonly DEFAULT_PYTHON_TARGET="3.12.12"

fail=0

has_tool() {
  command -v "$1" >/dev/null 2>&1
}

get_rust_target() {
  awk -F'"' '/^channel *=/ {print $2; exit}' "$ROOT_DIR/codex-rs/rust-toolchain.toml"
}

get_node_requirement() {
  awk -F'"' '/"node":/ {print $4; exit}' "$ROOT_DIR/package.json"
}

get_node_min_major() {
  sed -E 's/[^0-9]*([0-9]+).*/\1/'
}

get_python_target() {
  if [[ -n "${PERFECT_MIRROR_PYTHON_VERSION:-}" ]]; then
    printf '%s\n' "$PERFECT_MIRROR_PYTHON_VERSION"
    return
  fi

  if [[ -f "$ROOT_DIR/.python-version" ]]; then
    head -n 1 "$ROOT_DIR/.python-version" | tr -d '[:space:]'
    return
  fi

  printf '%s\n' "$DEFAULT_PYTHON_TARGET"
}

report_exact_check() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == "$expected" ]]; then
    printf 'PASS  %s %s\n' "$name" "$actual"
  else
    printf 'FAIL  %s expected %s but found %s\n' "$name" "$expected" "$actual"
    fail=1
  fi
}

report_min_major_check() {
  local name="$1"
  local requirement="$2"
  local expected_major="$3"
  local actual="$4"
  local actual_major

  if [[ "$actual" == "missing" ]]; then
    printf 'FAIL  %s expected %s but found %s\n' "$name" "$requirement" "$actual"
    fail=1
    return
  fi

  actual_major="${actual%%.*}"
  if [[ "$actual_major" =~ ^[0-9]+$ ]] && (( actual_major >= expected_major )); then
    printf 'PASS  %s %s satisfies %s\n' "$name" "$actual" "$requirement"
  else
    printf 'FAIL  %s expected %s but found %s\n' "$name" "$requirement" "$actual"
    fail=1
  fi
}

EXPECTED_RUST="$(get_rust_target)"
EXPECTED_NODE_REQUIREMENT="$(get_node_requirement)"
EXPECTED_NODE_MAJOR="$(printf '%s\n' "$EXPECTED_NODE_REQUIREMENT" | get_node_min_major)"
EXPECTED_PYTHON="$(get_python_target)"

readonly EXPECTED_RUST EXPECTED_NODE_REQUIREMENT EXPECTED_NODE_MAJOR EXPECTED_PYTHON

if [[ -z "$EXPECTED_RUST" || -z "$EXPECTED_NODE_REQUIREMENT" || -z "$EXPECTED_NODE_MAJOR" ]]; then
  printf 'FAIL  Could not derive runtime targets from repo metadata.\n' >&2
  exit 1
fi

uname_s="$(uname -s || true)"
if [[ "$uname_s" != "Darwin" ]]; then
  printf 'WARN  This script is intended for macOS mirrors; detected %s\n' "$uname_s"
fi

printf 'Target runtimes\n'
printf '  rustc:   %s (codex-rs/rust-toolchain.toml)\n' "$EXPECTED_RUST"
printf '  node:    %s (package.json engines.node)\n' "$EXPECTED_NODE_REQUIREMENT"
printf '  python3: %s (PERFECT_MIRROR_PYTHON_VERSION or fallback)\n' "$EXPECTED_PYTHON"
printf '\n'

if has_tool rustc; then
  rust_version_output="$(rustc -Vv)"
  rust_actual="$(awk '/^release:/ {print $2; exit}' <<<"$rust_version_output")"
else
  rust_actual="missing"
fi

if has_tool node; then
  node_actual="$(node -p 'process.versions.node')"
else
  node_actual="missing"
fi

if has_tool python3; then
  python_actual="$(
    python3 - <<'PY'
import platform
print(platform.python_version())
PY
  )"
else
  python_actual="missing"
fi

report_exact_check "rustc" "$EXPECTED_RUST" "$rust_actual"
report_min_major_check "node" "$EXPECTED_NODE_REQUIREMENT" "$EXPECTED_NODE_MAJOR" "$node_actual"
report_exact_check "python3" "$EXPECTED_PYTHON" "$python_actual"

if [[ $fail -ne 0 ]]; then
  printf '\nRemediation commands\n'
  printf '  rustup toolchain install %s && rustup default %s\n' "$EXPECTED_RUST" "$EXPECTED_RUST"
  printf '  volta install node@%s\n' "$EXPECTED_NODE_MAJOR"
  printf '  pyenv install %s && pyenv global %s\n' "$EXPECTED_PYTHON" "$EXPECTED_PYTHON"
  printf '  mise use -g rust@%s node@%s python@%s\n' "$EXPECTED_RUST" "$EXPECTED_NODE_MAJOR" "$EXPECTED_PYTHON"
  printf '  export PERFECT_MIRROR_PYTHON_VERSION=%s  # override the fallback target if needed\n' "$EXPECTED_PYTHON"
  exit 1
fi

printf '\nPASS  Codex runtime parity check passed.\n'
