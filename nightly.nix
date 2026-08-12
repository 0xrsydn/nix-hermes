# Nightly: HEAD of NousResearch/hermes-agent main branch.
# Auto-updated by scripts/update-nightly.sh — do not edit manually.
{ pkgs }:
pkgs.callPackage ./package.nix {
  pinVersion = "0.20.0-unstable-2026-08-12.76d832d3";
  pinRev = "76d832d3857551a029c4b39c23945eb47c16fe5b";
  pinHash = "sha256-PxPrQ//AlMou4cbVB1ceSJT+65dP9iwK5eUzPyUwkac=";
}
