# Nightly: HEAD of NousResearch/hermes-agent main branch.
# Auto-updated by scripts/update-nightly.sh — do not edit manually.
{ pkgs }:
pkgs.callPackage ./package.nix {
  pinVersion = "0.21.1-unstable-2026-09-08.866332bf";
  pinRev = "866332bfb52c46e543143b2620a9aeee8bce9c77";
  pinHash = "sha256-oG88zzH4G0wXRwZNTYdfJNPQCwWg5/ITLUrBhudbmuA=";
}
