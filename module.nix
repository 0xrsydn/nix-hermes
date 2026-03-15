self:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.hermes-agent;
  hermes-agent = self.packages.${pkgs.system}.hermes-agent;
in
{
  options.services.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent gateway service";

    package = lib.mkOption {
      type = lib.types.package;
      default = hermes-agent;
      description = "The hermes-agent package to use.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "hermes";
      description = "User under which Hermes Agent runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "hermes";
      description = "Group under which Hermes Agent runs.";
    };

    homeDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/hermes";
      description = "Home directory for Hermes Agent state.";
    };

    workDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.homeDir}/workspace";
      defaultText = lib.literalExpression ''"''${cfg.homeDir}/workspace"'';
      description = "Working directory for Hermes Agent.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to an environment file containing secrets (API keys, tokens).
        This file should contain lines like:
          ANTHROPIC_API_KEY=sk-...
          TELEGRAM_TOKEN=...
          OPENROUTER_API_KEY=...
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the Hermes Agent service.";
      example = lib.literalExpression ''
        {
          HERMES_DEFAULT_MODEL = "anthropic/claude-sonnet-4-20250514";
        }
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra command-line arguments to pass to hermes gateway.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to make available on PATH.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.homeDir;
      createHome = true;
      description = "Hermes Agent service user";
    };

    users.groups.${cfg.group} = { };

    systemd.services.hermes-agent = {
      description = "Hermes Agent Gateway";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = cfg.homeDir;
        HERMES_HOME = "${cfg.homeDir}/.hermes";
      } // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.workDir;
        ExecStart = lib.concatStringsSep " " ([
          "${cfg.package}/bin/hermes"
          "gateway"
        ] ++ cfg.extraArgs);
        Restart = "on-failure";
        RestartSec = 5;
        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = false;
        ReadWritePaths = [ cfg.homeDir ];
        PrivateTmp = true;
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };

      path = [ cfg.package ] ++ cfg.extraPackages;
    };
  };
}
