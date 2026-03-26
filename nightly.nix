# Nightly: HEAD of NousResearch/hermes-agent main branch.
# Auto-updated by scripts/update-nightly.sh — do not edit manually.
{ pkgs }:
pkgs.callPackage ./package.nix {
  pinVersion = "0.4.0-unstable-2026-03-25";
  pinRev = "e5691eed38716bce6d55fa83e62d92e3c327c437";
  pinHash = "sha256-+tJLd9PSdULdm4gsoWaonRx9NrZsNiiZ0wMUOP7Adek=";
}
