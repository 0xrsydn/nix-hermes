# Nightly: HEAD of NousResearch/hermes-agent main branch.
# Auto-updated by scripts/update-nightly.sh — do not edit manually.
{ pkgs }:
pkgs.callPackage ./package.nix {
  pinVersion = "0.19.0-unstable-2026-07-22.9eb7b1a6";
  pinRev = "9eb7b1a6b1ffdd4ad1a85aee3f38edceee2b927f";
  pinHash = "sha256-baXMhFvdjbw6nW0TChPWlBZrCRxFCnyLJ1Pe7IjGDUA=";
}
