#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/update-common.sh
source "$repo_root/scripts/update-common.sh"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

printf 'error: hash mismatch\n  got:    sha256-AbCd0123+/=\n' >"$log"
[[ "$(extract_sri_hash "$log")" == "sha256-AbCd0123+/=" ]]

printf 'specified: sha256-old\n       got: sha256-newValue=\n' >"$log"
[[ "$(extract_sri_hash "$log")" == "sha256-newValue=" ]]

printf 'an unrelated dependency failure\n' >"$log"
[[ -z "$(extract_sri_hash "$log")" ]]

status=$(run_validation "$log" bash -c 'echo dependency-broke; exit 42')
[[ "$status" == "failed" ]]
grep -q dependency-broke "$log"

status=$(run_validation "$log" bash -c 'echo all-good')
[[ "$status" == "passed" ]]
grep -q all-good "$log"
