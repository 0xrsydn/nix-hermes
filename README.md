# nix-hermes

Nix package and NixOS module for [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research.

## Quick Start

### Flake usage

```nix
{
  inputs.nix-hermes.url = "github:0xrsydn/nix-hermes";

  outputs = { self, nixpkgs, nix-hermes, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        nix-hermes.nixosModules.hermes-agent
        {
          services.hermes-agent = {
            enable = true;
            environmentFile = "/run/secrets/hermes-env";  # API keys
          };
        }
      ];
    };
  };
}
```

### Just the package

```bash
nix run github:0xrsydn/nix-hermes -- --help
```

### NixOS module options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the Hermes Agent gateway service |
| `user` | string | `"hermes"` | Service user |
| `group` | string | `"hermes"` | Service group |
| `homeDir` | path | `/var/lib/hermes` | State directory |
| `workDir` | path | `${homeDir}/workspace` | Working directory |
| `environmentFile` | path | `null` | Secrets file (API keys, tokens) |
| `extraEnvironment` | attrs | `{}` | Extra env vars |
| `extraArgs` | list | `[]` | Extra CLI args for `hermes gateway` |
| `extraPackages` | list | `[]` | Extra packages on PATH |

### Environment file example

```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENROUTER_API_KEY=sk-or-...
TELEGRAM_TOKEN=123456:ABC...
OPENAI_API_KEY=sk-...
```

## What's included

- **`hermes`** — Interactive CLI
- **`hermes-agent`** — Agent runner
- **`hermes-acp`** — ACP adapter
- **NixOS module** — systemd service for gateway mode
- Runtime deps wrapped: Node.js 22, ripgrep, ffmpeg, git

## Development

```bash
nix develop  # Enter dev shell with hermes on PATH
nix build    # Build the package
```

## License

MIT (same as upstream)
