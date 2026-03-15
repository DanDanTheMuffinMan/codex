#!/usr/bin/env bash
set -euo pipefail

EXPECTED_RUST="1.89.0"
EXPECTED_NODE="20.19.6"
EXPECTED_PYTHON="3.12.12"

report_check() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == "$expected" ]]; then
    printf "✅ %s %s\n" "$name" "$actual"
  else
    printf "❌ %s expected %s but found %s\n" "$name" "$expected" "$actual"
  fi
}

if command -v rustc >/dev/null 2>&1; then
  rust_actual="$(rustc --version | awk '{print $2}')"
else
  rust_actual="missing"
fi

if command -v node >/dev/null 2>&1; then
  node_actual="$(node --version | sed 's/^v//')"
else
  node_actual="missing"
fi

if command -v python3 >/dev/null 2>&1; then
  python_actual="$(python3 --version | sed 's/^Python //')"
else
  python_actual="missing"
fi

printf "Checking runtime parity...\n"
report_check "Rust" "$EXPECTED_RUST" "$rust_actual"
report_check "Node" "$EXPECTED_NODE" "$node_actual"
report_check "Python" "$EXPECTED_PYTHON" "$python_actual"

echo
echo "If any version is mismatched, run one of the following fixes:"
echo
cat <<'FIXES'
# Rust
rustup toolchain install 1.89.0
rustup override set 1.89.0

# Node via mise
mise use -g node@20.19.6

# Python via mise
mise use -g python@3.12.12
FIXES
