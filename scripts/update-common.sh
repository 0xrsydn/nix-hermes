#!/usr/bin/env bash

set_output() {
  local name=$1 value=$2
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$name" "$value" >>"$GITHUB_OUTPUT"
  fi
}

extract_sri_hash() {
  sed -nE 's/.*got:[[:space:]]*(sha256-[A-Za-z0-9+\/=]+).*/\1/p' "$1" | head -1
}

realize_flake_source() {
  nix build "$1.src" --no-link --print-out-paths 2>/dev/null | tail -1 || true
}

current_nix_system() {
  nix eval --impure --raw --expr builtins.currentSystem
}

publish_summary() {
  local report=$1
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" && -f "$report" ]]; then
    cat "$report" >>"$GITHUB_STEP_SUMMARY"
  fi
}

# Validation failure is data for the candidate PR, not a reason to discard it.
run_validation() {
  local log_file=$1
  shift
  if "$@" >"$log_file" 2>&1; then
    printf 'passed\n'
  else
    printf 'failed\n'
  fi
}
