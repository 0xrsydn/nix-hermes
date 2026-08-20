# Nightly: HEAD of NousResearch/hermes-agent main branch.
# Auto-updated by scripts/update-nightly.sh — do not edit manually.
{ pkgs }:
pkgs.callPackage ./package.nix {
  pinVersion = "0.20.4-unstable-2026-08-20.68518411";
  pinRev = "6851841112e921537eb7195ef6e8be7d2ca2d2f6";
  pinHash = "sha256-xt+9SK8IV7qQYP4c4/cVFOjgQNYhgaR/yAVTD86UsuA=";
}
