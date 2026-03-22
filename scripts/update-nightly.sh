#!/usr/bin/env bash
set -euo pipefail

# Auto-update nightly.nix to track HEAD of NousResearch/hermes-agent main branch.
# Designed to run in GitHub Actions (see .github/workflows/update-nightly.yml).

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
nightly_file="$repo_root/nightly.nix"

log() {
  printf '>> %s\n' "$*"
}

# --- Resolve HEAD of main ---
log "Fetching HEAD of NousResearch/hermes-agent main branch"
head_sha=$(git ls-remote https://github.com/NousResearch/hermes-agent.git refs/heads/main | awk '{print $1}')
if [[ -z "$head_sha" ]]; then
  echo "Failed to resolve HEAD of main" >&2
  exit 1
fi
log "HEAD SHA: $head_sha"

# --- Compare with current ---
current_rev=$(awk -F'"' '/pinRev = /{print $2}' "$nightly_file" | head -1)
log "Current pinned rev: $current_rev"

if [[ "$current_rev" == "$head_sha" ]]; then
  log "Already up to date ($current_rev). Nothing to do."
  exit 0
fi
log "Update available: ${current_rev:0:12} → ${head_sha:0:12}"

# --- Determine base version from package.nix ---
base_version=$(awk -F'"' '/pinVersion \? "/{print $2}' "$repo_root/package.nix" | head -1)
if [[ -z "$base_version" ]]; then
  base_version="0.0.0"
fi
nightly_version="${base_version}-unstable-$(date -u +%Y-%m-%d)"
log "Nightly version: $nightly_version"

# --- Update nightly.nix with new rev and empty hash ---
perl -0pi -e "s|pinVersion = \"[^\"]+\";|pinVersion = \"${nightly_version}\";|" "$nightly_file"
perl -0pi -e "s|pinRev = \"[^\"]+\";|pinRev = \"${head_sha}\";|" "$nightly_file"
perl -0pi -e 's|pinHash = "[^"]*";|pinHash = "";|' "$nightly_file"

# --- Prefetch to get correct hash ---
build_log=$(mktemp)
log "Running nix build to compute source hash..."
if nix build .#hermes-agent-nightly --accept-flake-config >"$build_log" 2>&1; then
  log "Build succeeded with empty hash?! Unexpected, but OK."
  source_hash=""
else
  source_hash=$(grep -oP 'got: *\Ksha256-[A-Za-z0-9+/=]+' "$build_log" | head -1 || true)
  if [[ -z "$source_hash" ]]; then
    log "Build failed but couldn't extract hash. Build log:"
    tail -50 "$build_log" >&2
    # Restore original
    git checkout -- "$nightly_file"
    rm -f "$build_log"
    exit 1
  fi
fi
rm -f "$build_log"
log "Source hash: $source_hash"

# Update with the correct hash
if [[ -n "$source_hash" ]]; then
  perl -0pi -e "s|pinHash = \"[^\"]*\";|pinHash = \"${source_hash}\";|" "$nightly_file"
fi

# --- Validate build ---
build_log=$(mktemp)
log "Validating full nightly build..."
if ! nix build .#hermes-agent-nightly --accept-flake-config >"$build_log" 2>&1; then
  log "Build validation FAILED. This likely means dependencies changed upstream."
  log "Build log (last 100 lines):"
  tail -100 "$build_log" >&2
  git checkout -- "$nightly_file"
  rm -f "$build_log"
  exit 1
fi
rm -f "$build_log"
log "Build validation PASSED ✅"

# --- Commit and push ---
if git diff --quiet "$nightly_file"; then
  log "No changes to commit (shouldn't happen)"
  exit 0
fi

log "Committing nightly update"
git add "$nightly_file"
git commit -m "🤖 bump hermes-agent-nightly to ${head_sha:0:12} (${nightly_version})" \
  -m "Upstream HEAD: https://github.com/NousResearch/hermes-agent/commit/${head_sha}" \
  -m "Tests: nix build .#hermes-agent-nightly (passed)"

log "Pushing to main"
git fetch origin main
git rebase origin/main
git push origin HEAD:main

log "Done! Updated hermes-agent-nightly to ${head_sha:0:12} (${nightly_version})"
