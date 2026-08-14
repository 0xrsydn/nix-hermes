# Nightly: HEAD of NousResearch/hermes-agent main branch.
# Auto-updated by scripts/update-nightly.sh — do not edit manually.
{ pkgs }:
pkgs.callPackage ./package.nix {
  pinVersion = "0.20.1-unstable-2026-08-14.9504edba";
  pinRev = "9504edbaea29ce249864a1be05819d972f8fae8d";
  pinHash = "sha256-hZHeylSgU71r/x3WMOrmcARcKSx5y17l9vwFgbde5ks=";
}
