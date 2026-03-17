# Hermes Agent Configuration Map

**Source:** `hermes_cli/config.py` + `gateway/config.py` (v0.2.0)

Everything below can be set declaratively via the NixOS module's `services.hermes-agent.config` option (rendered as `cli-config.yaml`), `environmentFiles` (secrets), or `environment` (non-secret env vars).

---

## 1. Model & Provider

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `model` | string | `"anthropic/claude-opus-4.6"` | Default model (`provider/model` format) |
| `toolsets` | list | `["hermes-cli"]` | Enabled toolsets (e.g. `["all"]`, `["hermes-cli", "browser"]`) |

**Auth providers** (resolved automatically based on env vars / OAuth):
- Nous Portal (OAuth) → `hermes login --provider nous`
- OpenAI Codex (OAuth) → `hermes login --provider openai-codex`
- OpenRouter → `OPENROUTER_API_KEY`
- Z.AI / GLM → `GLM_API_KEY` / `ZAI_API_KEY`
- Kimi → `KIMI_API_KEY`
- MiniMax → `MINIMAX_API_KEY`
- Anthropic → `ANTHROPIC_API_KEY` or Claude Code OAuth

---

## 2. Agent Behavior

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `agent.max_turns` | int | `90` | Max tool-calling iterations per conversation |

---

## 3. Terminal / Sandbox

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `terminal.backend` | string | `"local"` | `local` / `docker` / `singularity` / `modal` / `daytona` / `ssh` |
| `terminal.cwd` | string | `"."` | Working directory for commands |
| `terminal.timeout` | int | `180` | Command timeout (seconds) |
| `terminal.docker_image` | string | `"nikolaik/python-nodejs:..."` | Docker image |
| `terminal.singularity_image` | string | ... | Singularity image |
| `terminal.modal_image` | string | ... | Modal image |
| `terminal.daytona_image` | string | ... | Daytona image |
| `terminal.container_cpu` | int | `1` | Container CPU limit |
| `terminal.container_memory` | int | `5120` | Container memory (MB) |
| `terminal.container_disk` | int | `51200` | Container disk (MB) |
| `terminal.container_persistent` | bool | `true` | Persist filesystem across sessions |
| `terminal.docker_volumes` | list | `[]` | Docker volume mounts (`host:container`) |

**SSH backend env vars:**
- `TERMINAL_SSH_HOST`, `TERMINAL_SSH_USER`, `TERMINAL_SSH_KEY`

---

## 4. Context Compression

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `compression.enabled` | bool | `true` | Auto-compress long conversations |
| `compression.threshold` | float | `0.50` | Context usage % to trigger compression |
| `compression.summary_model` | string | `"google/gemini-3-flash-preview"` | Model for summaries |
| `compression.summary_provider` | string | `"auto"` | Provider for compression model |

---

## 5. Auxiliary Models

Side-task models (vision, web extraction, etc). Each has the same schema:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `auxiliary.<task>.provider` | string | `"auto"` | Provider override |
| `auxiliary.<task>.model` | string | `""` | Model override |
| `auxiliary.<task>.base_url` | string | `""` | Direct endpoint URL |
| `auxiliary.<task>.api_key` | string | `""` | API key for endpoint |

**Tasks:** `vision`, `web_extract`, `compression`, `session_search`, `skills_hub`, `mcp`, `flush_memories`

---

## 6. Delegation (Subagents)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `delegation.model` | string | `""` | Model for subagents (empty = inherit parent) |
| `delegation.provider` | string | `""` | Provider for subagents |
| `delegation.base_url` | string | `""` | Direct endpoint for subagents |
| `delegation.api_key` | string | `""` | API key for delegation endpoint |

---

## 7. Display

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `display.compact` | bool | `false` | Compact output mode |
| `display.personality` | string | `"kawaii"` | UI personality |
| `display.resume_display` | string | `"full"` | Session resume display |
| `display.bell_on_complete` | bool | `false` | Bell sound on completion |
| `display.show_reasoning` | bool | `false` | Show model reasoning |
| `display.skin` | string | `"default"` | UI skin |

---

## 8. Memory

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `memory.memory_enabled` | bool | `true` | Persistent curated memory |
| `memory.user_profile_enabled` | bool | `true` | User profile memory |
| `memory.memory_char_limit` | int | `2200` | Max chars for memory context |
| `memory.user_char_limit` | int | `1375` | Max chars for user profile |

---

## 9. Browser

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `browser.inactivity_timeout` | int | `120` | Browser auto-close (seconds) |
| `browser.record_sessions` | bool | `false` | Record browser sessions as WebM |

---

## 10. Checkpoints (Filesystem Snapshots)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `checkpoints.enabled` | bool | `false` | Auto-snapshot before destructive ops |
| `checkpoints.max_snapshots` | int | `50` | Max checkpoints per directory |

---

## 11. TTS (Text-to-Speech)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `tts.provider` | string | `"edge"` | `edge` (free) / `elevenlabs` (premium) / `openai` |
| `tts.edge.voice` | string | `"en-US-AriaNeural"` | Edge TTS voice |
| `tts.elevenlabs.voice_id` | string | `"pNInz6obpgDQGcFmaJgB"` | ElevenLabs voice ID |
| `tts.elevenlabs.model_id` | string | `"eleven_multilingual_v2"` | ElevenLabs model |
| `tts.openai.model` | string | `"gpt-4o-mini-tts"` | OpenAI TTS model |
| `tts.openai.voice` | string | `"alloy"` | OpenAI TTS voice |

---

## 12. STT (Speech-to-Text)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `stt.enabled` | bool | `true` | Enable voice transcription |
| `stt.provider` | string | `"local"` | `local` (faster-whisper) / `groq` / `openai` |
| `stt.local.model` | string | `"base"` | Local model size: tiny/base/small/medium/large-v3 |
| `stt.openai.model` | string | `"whisper-1"` | OpenAI STT model |

---

## 13. Voice (Interactive)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `voice.record_key` | string | `"ctrl+b"` | Push-to-talk key |
| `voice.max_recording_seconds` | int | `120` | Max recording length |
| `voice.auto_tts` | bool | `false` | Auto-speak responses |
| `voice.silence_threshold` | int | `200` | RMS silence threshold |
| `voice.silence_duration` | float | `3.0` | Seconds of silence → auto-stop |

---

## 14. Human Delay (Anti-Detection)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `human_delay.mode` | string | `"off"` | `off` / `on` / `adaptive` |
| `human_delay.min_ms` | int | `800` | Min delay (ms) |
| `human_delay.max_ms` | int | `2500` | Max delay (ms) |

---

## 15. Security

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `security.redact_secrets` | bool | `true` | Redact API keys from tool output |
| `security.tirith_enabled` | bool | `true` | Pre-exec scanning via tirith |
| `security.tirith_path` | string | `"tirith"` | Path to tirith binary |
| `security.tirith_timeout` | int | `5` | Tirith scan timeout (seconds) |
| `security.tirith_fail_open` | bool | `true` | Allow exec if tirith fails |

---

## 16. Discord

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `discord.require_mention` | bool | `true` | Require @mention to respond in channels |
| `discord.free_response_channels` | string | `""` | Comma-separated channel IDs for free response |
| `discord.auto_thread` | bool | `true` | Auto-create threads on @mention |

---

## 17. Session Reset Policy

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `session_reset.mode` | string | `"both"` | `daily` / `idle` / `both` / `none` |
| `session_reset.at_hour` | int | `4` | Daily reset hour (0-23, local time) |
| `session_reset.idle_minutes` | int | `1440` | Idle timeout before reset (minutes) |

---

## 18. Miscellaneous

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `timezone` | string | `""` | IANA timezone (empty = server-local) |
| `command_allowlist` | list | `[]` | Permanently allowed dangerous commands |
| `quick_commands` | dict | `{}` | User-defined slash commands (exec type) |
| `personalities` | dict | `{}` | Custom personality prompts |
| `prefill_messages_file` | string | `""` | Path to JSON prefill messages |
| `honcho` | dict | `{}` | Honcho AI-native memory overrides |

---

## 19. MCP Servers

Defined via `services.hermes-agent.mcpServers` in the NixOS module:

```nix
mcpServers = {
  my-server = {
    command = "npx";
    args = [ "-y" "my-mcp-server" ];
    env = { API_KEY = "..."; };
    timeout = 30;
  };
};
```

Merged into `config.mcp_servers` in the rendered YAML.

---

## 20. Fallback Model (Failover)

Not in defaults — must be explicitly configured:

```yaml
fallback_model:
  provider: openrouter     # openrouter | nous | openai-codex | zai | kimi-coding | minimax
  model: anthropic/claude-sonnet-4
  # Optional for custom endpoints:
  # base_url: "http://..."
  # api_key_env: "MY_CUSTOM_KEY"
```

Triggers on: 429 (rate limit), 529 (overload), 503 (service error), connection failures.

---

## 21. Environment Variables (Secrets via `environmentFiles`)

### Provider Keys
| Variable | Provider |
|----------|----------|
| `OPENROUTER_API_KEY` | OpenRouter (default fallback) |
| `GLM_API_KEY` / `ZAI_API_KEY` | Z.AI / GLM |
| `KIMI_API_KEY` | Kimi / Moonshot |
| `MINIMAX_API_KEY` | MiniMax (international) |
| `MINIMAX_CN_API_KEY` | MiniMax (China) |
| `ANTHROPIC_API_KEY` | Anthropic direct |
| `ANTHROPIC_TOKEN` | Anthropic OAuth/setup token |

### Tool Keys
| Variable | Tool |
|----------|------|
| `FIRECRAWL_API_KEY` | Web search/scraping |
| `BROWSERBASE_API_KEY` | Cloud browser |
| `FAL_KEY` | Image generation |
| `ELEVENLABS_API_KEY` | Premium TTS |
| `VOICE_TOOLS_OPENAI_KEY` | Whisper STT + OpenAI TTS |
| `GITHUB_TOKEN` | Skills Hub |
| `HONCHO_API_KEY` | AI-native memory |
| `TINKER_API_KEY` | RL training |
| `WANDB_API_KEY` | Experiment tracking |

### Messaging Tokens
| Variable | Platform |
|----------|----------|
| `TELEGRAM_BOT_TOKEN` | Telegram |
| `TELEGRAM_ALLOWED_USERS` | Telegram user whitelist |
| `DISCORD_BOT_TOKEN` | Discord |
| `DISCORD_ALLOWED_USERS` | Discord user whitelist |
| `SLACK_BOT_TOKEN` | Slack |
| `SLACK_APP_TOKEN` | Slack (Socket Mode) |
| `SIGNAL_HTTP_URL` | Signal |
| `SIGNAL_ACCOUNT` | Signal |
| `HASS_TOKEN` | Home Assistant |
| `EMAIL_ADDRESS` / `EMAIL_PASSWORD` / `EMAIL_IMAP_HOST` / `EMAIL_SMTP_HOST` | Email |
| `GATEWAY_ALLOW_ALL_USERS` | Allow all users (global) |

### Agent Settings
| Variable | Description |
|----------|-------------|
| `MESSAGING_CWD` | Working directory for messaging |
| `SUDO_PASSWORD` | Sudo password for terminal |
| `HERMES_MAX_ITERATIONS` | Max iterations override |

---

## 22. Custom Providers (config.yaml)

```yaml
custom_providers:
  - name: "local-vllm"
    base_url: "http://localhost:8000/v1"
    api_key: ""  # optional
```

Use with: `hermes chat --provider custom:local-vllm`

---

## Summary: What Goes Where

| What | Where | NixOS Module Option |
|------|-------|---------------------|
| Model, toolsets, display, terminal, etc. | `cli-config.yaml` | `config = { ... }` |
| API keys, tokens, passwords | `.env` / env vars | `environmentFiles = [ "/run/secrets/hermes.env" ]` |
| OAuth tokens (Nous, Codex) | `auth.json` | Runtime via `hermes login` (persistent) |
| MCP servers | `cli-config.yaml` | `mcpServers = { ... }` |
| SOUL.md, AGENTS.md, USER.md | Workspace files | `documents = { ... }` |
| Gateway platform config | env vars or `gateway.json` | `environmentFiles` |
