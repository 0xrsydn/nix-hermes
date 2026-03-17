#!/usr/bin/env bash
set -euo pipefail

# Auto-update nix-hermes-agent to track latest stable release from NousResearch/hermes-agent.
# Designed to run in GitHub Actions (see .github/workflows/update-pins.yml).
# Similar to nix-openclaw's update-pins.sh but tracks releases instead of HEAD.

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
package_file="$repo_root/package.nix"

log() {
  printf '>> %s\n' "$*"
}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed." >&2
  exit 1
fi

# --- Resolve latest stable release ---
log "Fetching latest release from NousResearch/hermes-agent"
release_json=$(gh api /repos/NousResearch/hermes-agent/releases/latest 2>/dev/null || true)
if [[ -z "$release_json" ]]; then
  echo "Failed to fetch latest release" >&2
  exit 1
fi

release_tag=$(printf '%s' "$release_json" | jq -r '.tag_name // empty')
release_name=$(printf '%s' "$release_json" | jq -r '.name // empty')
if [[ -z "$release_tag" ]]; then
  echo "No release tag found" >&2
  exit 1
fi
log "Latest release: $release_tag ($release_name)"

# Extract version from release name or tag (e.g. "Hermes Agent v0.3.0 (v2026.3.17)" → "0.3.0")
upstream_version=$(printf '%s' "$release_name" | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
if [[ -z "$upstream_version" ]]; then
  # Fallback: try tag itself
  upstream_version=$(printf '%s' "$release_tag" | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
fi
if [[ -z "$upstream_version" ]]; then
  echo "Could not parse version from release tag=$release_tag name=$release_name" >&2
  exit 1
fi
log "Parsed version: $upstream_version"

# --- Compare with current ---
current_version=$(awk -F'"' '/^  version = /{print $2}' "$package_file" | head -1)
log "Current pinned version: $current_version"

if [[ "$current_version" == "$upstream_version" ]]; then
  log "Already up to date ($current_version). Nothing to do."
  exit 0
fi
log "Update available: $current_version → $upstream_version"

# --- Resolve the commit SHA for the release tag ---
tag_sha=$(gh api "/repos/NousResearch/hermes-agent/git/ref/tags/${release_tag}" --jq '.object.sha' 2>/dev/null || true)
if [[ -z "$tag_sha" ]]; then
  # Maybe it's an annotated tag — dereference
  tag_sha=$(gh api "/repos/NousResearch/hermes-agent/git/ref/tags/${release_tag}" --jq '.object.sha' 2>/dev/null || true)
  if [[ -n "$tag_sha" ]]; then
    # Check if it's an annotated tag (type=tag) and dereference
    tag_type=$(gh api "/repos/NousResearch/hermes-agent/git/tags/${tag_sha}" --jq '.object.type // empty' 2>/dev/null || true)
    if [[ "$tag_type" == "commit" ]]; then
      tag_sha=$(gh api "/repos/NousResearch/hermes-agent/git/tags/${tag_sha}" --jq '.object.sha' 2>/dev/null || true)
    fi
  fi
fi

if [[ -z "$tag_sha" ]]; then
  # Last resort: ls-remote
  tag_sha=$(git ls-remote https://github.com/NousResearch/hermes-agent.git "refs/tags/${release_tag}" | awk '{print $1}' || true)
fi

if [[ -z "$tag_sha" ]]; then
  echo "Failed to resolve commit SHA for tag $release_tag" >&2
  exit 1
fi
log "Release commit SHA: $tag_sha"

# --- Prefetch source ---
source_url="https://github.com/NousResearch/hermes-agent/archive/${tag_sha}.tar.gz"
log "Prefetching source tarball (with submodules via fetchFromGitHub)..."

# Use nix-prefetch-url for the base archive, but we need fetchFromGitHub hash (includes submodules).
# Best approach: temporarily update package.nix with empty hash and let nix build tell us the right one.
# Or use nix store prefetch-file for the tarball (no submodules).
# Since the package uses fetchSubmodules = true, we need the fetchFromGitHub hash.

# Strategy: use nix to evaluate the hash by building with a fake hash
log "Computing fetchFromGitHub hash (with submodules)..."

# Save original
cp "$package_file" "$package_file.bak"

# Update version, rev, and set hash to empty
perl -0pi -e "s|version = \"[^\"]+\";|version = \"${upstream_version}\";|" "$package_file"
perl -0pi -e "s|rev = \"[^\"]+\";|rev = \"${tag_sha}\";|" "$package_file"
perl -0pi -e 's|hash = "sha256-[^"]+";|hash = "";|' "$package_file"

# Build and capture the correct hash from the error
build_log=$(mktemp)
log "Running nix build to get correct hash..."
if nix build .#hermes-agent --accept-flake-config >"$build_log" 2>&1; then
  log "Build succeeded with empty hash?! Unexpected, but OK."
  source_hash=""
else
  source_hash=$(grep -oP 'got: *\Ksha256-[A-Za-z0-9+/=]+' "$build_log" | head -1 || true)
  if [[ -z "$source_hash" ]]; then
    log "Build failed but couldn't extract hash. Build log:"
    tail -50 "$build_log" >&2
    cp "$package_file.bak" "$package_file"
    rm -f "$build_log" "$package_file.bak"
    exit 1
  fi
fi
rm -f "$build_log"
log "Source hash: $source_hash"

# Update with the correct hash
if [[ -n "$source_hash" ]]; then
  perl -0pi -e "s|hash = \"[^\"]*\";|hash = \"${source_hash}\";|" "$package_file"
fi

# --- Validate build ---
build_log=$(mktemp)
log "Validating full build..."
if ! nix build .#hermes-agent --accept-flake-config >"$build_log" 2>&1; then
  log "Build validation FAILED. This likely means dependencies changed upstream."
  log "Build log (last 100 lines):"
  tail -100 "$build_log" >&2
  cp "$package_file.bak" "$package_file"
  rm -f "$build_log" "$package_file.bak"
  exit 1
fi
rm -f "$build_log" "$package_file.bak"
log "Build validation PASSED ✅"

# --- Commit and push ---
if git diff --quiet "$package_file"; then
  log "No changes to commit (shouldn't happen)"
  exit 0
fi

log "Committing update"
git add "$package_file"
git commit -m "🤖 bump hermes-agent ${current_version} → ${upstream_version} (${release_tag})" \
  -m "Upstream: https://github.com/NousResearch/hermes-agent/releases/tag/${release_tag}" \
  -m "Tests: nix build .#hermes-agent (passed)"

log "Pushing to main"
git fetch origin main
git rebase origin/main
git push origin HEAD:main

log "Done! Updated hermes-agent to ${upstream_version} (${release_tag})"
