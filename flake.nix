{
  description = "Nix package and NixOS module for Hermes Agent by Nous Research";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;
        nightlyPackage = self.packages.${system}.hermes-agent-nightly;
        nightlyChecks =
          (import ./checks.nix {
            inherit pkgs;
            hermes-agent = nightlyPackage;
          })
          // {
            skills-coexistence = import ./tests/skills-coexistence.nix {
              inherit self nixpkgs system;
              hermes-agent = nightlyPackage;
            };
          };
        nightlyCheckSuite = pkgs.linkFarm "hermes-agent-nightly-checks" (
          lib.mapAttrsToList (name: path: { inherit name path; }) nightlyChecks
        );
      in
      {
        packages = {
          hermes-agent = pkgs.callPackage ./package.nix { };
          hermes-agent-nightly = import ./nightly.nix { inherit pkgs; };
          default = self.packages.${system}.hermes-agent;
        };

        checks =
          (import ./checks.nix {
            inherit pkgs;
            inherit (self.packages.${system}) hermes-agent;
          })
          // {
            skills-coexistence = import ./tests/skills-coexistence.nix {
              inherit self nixpkgs system;
            };
          };

        # Nightly tracks mutable upstream HEAD. Keep it available for explicit
        # validation without making upstream breakage fail the stable channel.
        legacyPackages.nightlyChecks = nightlyChecks // {
          all = nightlyCheckSuite;
        };

        devShells.default = pkgs.mkShell {
          packages = [ self.packages.${system}.hermes-agent ];
        };
      }
    )
    // {
      nixosModules = {
        hermes-agent = import ./module.nix self;
        default = self.nixosModules.hermes-agent;
      };

      overlays.default = final: prev: {
        hermes-agent = final.callPackage ./package.nix { };
        hermes-agent-nightly = import ./nightly.nix { pkgs = final; };
      };
    };
}
