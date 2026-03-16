# Golden Paths

nix-hermes-agent is opinionated: **there should be one obvious way to deploy**. Used reference from (Nix Openclaw Repository)[https://github.com/openclaw/nix-openclaw/blob/main/docs/golden-paths.md] but customized to what I need in the future, including for single nixos server, remote execution-first, then gradually applied to macOS (via nix-darwin) and development device normally.

A **Golden Path** is a supported topology + defaults + docs that:

- is secure by default
- is reproducible (pinned inputs)
- avoids manual state drift
- has a clear boundary between **Nix-managed config** and **runtime state**

If your setup doesn't match a Golden Path, it may still work — but you're on your own.

---

## GP1: Single NixOS Server ⭐ (recommended)

**Who it's for:** always-on server running gateway + agent on one box. Simplest and most battle-tested.

- Gateway: NixOS (systemd service)
- Terminal: local execution
- Networking: direct or Tailscale

```nix
services.hermes-agent = {
  enable = true;
  config.terminal.backend = "local";
  environmentFiles = [ config.sops.secrets."hermes/env".path ];
};
```

**This is what we run.** If you're unsure, start here.

## GP2: NixOS Gateway + Remote Execution

**Who it's for:** gateway on a lightweight VPS, heavy commands run on a separate machine via SSH or Docker.

- Gateway: NixOS VPS (systemd service)
- Terminal: SSH backend to a beefy box, or Docker container
- Networking: **Tailscale tailnet** (private, no public exposure)

```nix
services.hermes-agent = {
  enable = true;
  config.terminal = {
    backend = "ssh";
    ssh_host = "gpu-box";  # Tailscale hostname
    ssh_user = "agent";
    ssh_key = "/run/secrets/hermes-ssh-key";
    timeout = 300;
  };
};
```

### Why Tailscale?

- Private-by-default connectivity
- MagicDNS stable hostnames (no IP chasing)
- Easy to lock down with ACLs
- Already works with NixOS `services.tailscale`

## GP3: NixOS Gateway + macOS Node (future)

**Who it's for:** always-on gateway with macOS-only capabilities (screenshots, Accessibility, Spotlight, etc.).

- Gateway: NixOS (systemd service)
- Node: macOS (launchd service via darwin module)
- Networking: Tailscale

⚠️ **Not yet implemented.** Requires the darwin module (roadmap item). Use GP1 or GP2 for now.

## GP4: Laptop Dev

**Who it's for:** local experimentation, not always-on.

- Gateway: laptop (NixOS or `nix run`)
- Expect downtime, sleep, network changes
- Good for testing before deploying to GP1/GP2

```bash
nix run github:0xrsydn/nix-hermes-agent -- gateway
```

---

## Runtime State vs Nix-Managed Config

| Layer | Managed by | Survives rebuild? | Examples |
|-------|-----------|-------------------|----------|
| **Nix-managed** | `nixos-rebuild` | Overwritten | cli-config.yaml, SOUL.md, AGENTS.md, systemd unit |
| **Secrets** | sops-nix | Overwritten (from encrypted source) | API keys, OAuth tokens, SSH keys |
| **Runtime state** | Agent | ✅ Persists | Skills, memory, sessions, logs, cron jobs |

Key principle: Nix manages the **shape** of the system. The agent manages its own **state**.

---

## Roadmap

- [x] GP1: Single NixOS server
- [x] GP2: Remote execution (SSH/Docker backends)
- [ ] GP3: Darwin module for macOS
- [ ] Binary cache (garnix/cachix)
- [ ] Template flake (`nix flake init -t`)
- [ ] Structured skills option with package dependencies
