# Nightly: HEAD of NousResearch/hermes-agent main branch.
# Auto-updated by scripts/update-nightly.sh — do not edit manually.
{ pkgs }:
pkgs.callPackage ./package.nix {
  pinVersion = "0.20.3-unstable-2026-08-18.bdc9a810";
  pinRev = "bdc9a810f3990597b3f26203348e849e5128afb6";
  pinHash = "sha256-+eoh8rq+U+sflD35vXibjlikB7zS4nVrsJFl1kVdMU4=";
}
