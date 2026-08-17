# Nightly: HEAD of NousResearch/hermes-agent main branch.
# Auto-updated by scripts/update-nightly.sh — do not edit manually.
{ pkgs }:
pkgs.callPackage ./package.nix {
  pinVersion = "0.20.2-unstable-2026-08-17.3b9a963b";
  pinRev = "3b9a963b8e5cdb804a422755bed9a60fcd778273";
  pinHash = "sha256-fq0Qci8Ez0Bn7MVmz73kZfpl9zA+0bAKrOEt6ExKt8I=";
}
