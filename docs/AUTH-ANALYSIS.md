# Hermes Agent Authentication System Analysis

**Date:** 2026-03-16  
**Source:** `/nix/store/3nz25qic608jccip6a6m49da24dxibi8-hermes-agent-0.2.0`  
**Version:** 0.2.0

---

## 1. Auth Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HERMES AUTH RESOLUTION FLOW                         │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌──────────────┐
                              │   CLI Call   │
                              │ hermes chat  │
                              └──────┬───────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │   resolve_runtime_provider()   │
                    │   (runtime_provider.py)        │
                    └────────────────┬───────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
                    ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐
        │ Config-based provider │         │  resolve_provider()   │
        │ (config.yaml)         │         │  (auth.py)            │
        └───────────┬───────────┘         └───────────┬───────────┘
                    │                                 │
                    │         ┌───────────────────────┼───────────────────────┐
                    │         │                       │                       │
                    ▼         ▼                       ▼                       ▼
        ┌─────────────────────────────────────────────────────────────────────────┐
        │                        PROVIDER RESOLUTION PRIORITY                       │
        ├─────────────────────────────────────────────────────────────────────────┤
        │ 1. explicit --api-key / --base-url CLI args → openrouter                 │
        │ 2. active_provider in ~/.hermes/auth.json (OAuth providers)              │
        │ 3. OPENAI_API_KEY / OPENROUTER_API_KEY env vars → openrouter             │
        │ 4. Provider-specific env vars (GLM_API_KEY, KIMI_API_KEY, etc.)          │
        │ 5. Fallback → openrouter                                                 │
        └─────────────────────────────────────────────────────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
         ▼                           ▼                           ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│  OAUTH PROVIDERS │       │ API-KEY PROVIDERS│      │  OPENROUTER     │
│  (auth.json)     │       │  (env vars)      │      │  (default)      │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ • nous          │       │ • zai (GLM)     │       │ OPENROUTER_API_ │
│ • openai-codex  │       │ • kimi-coding   │       │ KEY or          │
│                 │       │ • minimax       │       │ OPENAI_API_KEY  │
│ Device Code →   │       │ • minimax-cn    │       │                 │
│ access_token    │       │ • anthropic     │       │ OpenRouter API  │
│ + refresh_token │       │                 │       │ or custom URL   │
│ + agent_key     │       │ Direct env vars │       │ via OPENAI_BASE │
│                 │       │ → runtime creds │       │ _URL            │
└────────┬────────┘       └────────┬────────┘       └────────┬────────┘
         │                         │                         │
         │                         │                         │
         ▼                         ▼                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          RUNTIME CREDENTIALS                                 │
│  {                                                                          │
│    "provider": "nous" | "openai-codex" | "zai" | ... | "openrouter",       │
│    "api_mode": "chat_completions" | "anthropic_messages" | "codex_responses",│
│    "base_url": "https://...",                                               │
│    "api_key": "...",                                                        │
│    "source": "portal" | "env" | "hermes-auth-store",                        │
│    "expires_at": "ISO timestamp" (OAuth only),                              │
│  }                                                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. auth.json Schema

**Location:** `~/.hermes/auth.json`  
**Version:** 1

```json
{
  "version": 1,
  "active_provider": "nous" | "openai-codex" | null,
  "providers": {
    "nous": {
      // OAuth device code flow tokens
      "portal_base_url": "https://portal.nousresearch.com",
      "inference_base_url": "https://inference-api.nousresearch.com/v1",
      "client_id": "hermes-cli",
      "scope": "inference:mint_agent_key",
      "token_type": "Bearer",
      
      // Core OAuth tokens
      "access_token": "eyJ...",
      "refresh_token": "rt_...",
      "obtained_at": "2026-03-16T00:00:00+00:00",
      "expires_at": "2026-03-16T01:00:00+00:00",
      "expires_in": 3600,
      
      // Minted agent key (short-lived inference key)
      "agent_key": "ak_...",
      "agent_key_id": "key-uuid",
      "agent_key_expires_at": "2026-03-16T00:30:00+00:00",
      "agent_key_expires_in": 1800,
      "agent_key_reused": false,
      "agent_key_obtained_at": "2026-03-16T00:00:00+00:00",
      
      // TLS config
      "tls": {
        "insecure": false,
        "ca_bundle": null
      }
    },
    
    "openai-codex": {
      // Codex OAuth tokens (stored in Hermes, not ~/.codex/)
      "tokens": {
        "access_token": "eyJ...",
        "refresh_token": "rt_..."
      },
      "last_refresh": "2026-03-16T00:00:00Z",
      "auth_mode": "chatgpt"
    }
  },
  "updated_at": "2026-03-16T00:00:00+00:00"
}
```

### Key Points:

- **Cross-process locking**: Uses file-based advisory lock (`auth.json.lock`) with 15s timeout
- **Atomic writes**: Writes to temp file, then `os.replace()` for crash safety
- **Permission restricted**: `chmod 0600` (owner read/write only)
- **Version field**: Schema version for future migrations

---

## 3. Per-Provider Auth Flow

### 3.1 Nous Portal (OAuth Device Code)

**Provider ID:** `nous`  
**Auth Type:** `oauth_device_code`

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      NOUS PORTAL OAUTH FLOW                              │
└─────────────────────────────────────────────────────────────────────────┘

  User runs: hermes login --provider nous
       │
       ▼
  ┌────────────────────────────────────────┐
  │ 1. POST /api/oauth/device/code         │
  │    → device_code, user_code,           │
  │      verification_uri_complete         │
  └───────────────────┬────────────────────┘
                      │
       ▼
  ┌────────────────────────────────────────┐
  │ 2. User opens URL, enters code         │
  │    Browser → Portal login → Authorize  │
  └───────────────────┬────────────────────┘
                      │
       ▼
  ┌────────────────────────────────────────┐
  │ 3. Poll /api/oauth/token               │
  │    (device_code grant)                 │
  │    → access_token, refresh_token       │
  └───────────────────┬────────────────────┘
                      │
       ▼
  ┌────────────────────────────────────────┐
  │ 4. Mint agent key                      │
  │    POST /api/oauth/agent-key           │
  │    Authorization: Bearer access_token  │
  │    → api_key (short-lived, 30min TTL)  │
  └───────────────────┬────────────────────┘
                      │
       ▼
  ┌────────────────────────────────────────┐
  │ 5. Store to ~/.hermes/auth.json        │
  │    Set active_provider = "nous"        │
  └────────────────────────────────────────┘
```

**Token Refresh:**
- Access token auto-refreshed when `expires_at < now + 120s`
- Agent key auto-re-minted when `agent_key_expires_at < now + 30min`
- Refresh uses `refresh_token` grant to `/api/oauth/token`
- If refresh fails with `invalid_grant`, user must re-login

**Code References:**
- `auth.py:1413-1505` — `_request_device_code()`, `_poll_for_token()`
- `auth.py:1507-1560` — `_refresh_access_token()`, `_mint_agent_key()`
- `auth.py:1625-1780` — `resolve_nous_runtime_credentials()`

---

### 3.2 OpenAI Codex (OAuth External)

**Provider ID:** `openai-codex`  
**Auth Type:** `oauth_external`

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      CODEX OAUTH FLOW                                    │
└─────────────────────────────────────────────────────────────────────────┘

  User runs: hermes login --provider openai-codex
       │
       ▼
  ┌────────────────────────────────────────┐
  │ 1. POST /api/accounts/deviceauth/usercode│
  │    client_id: app_EMoamEEZ73f0CkXaXp7hrann│
  │    → user_code, device_auth_id          │
  └───────────────────┬────────────────────┘
                      │
       ▼
  ┌────────────────────────────────────────┐
  │ 2. User opens auth.openai.com/codex/device│
  │    Enters user_code                     │
  └───────────────────┬────────────────────┘
                      │
       ▼
  ┌────────────────────────────────────────┐
  │ 3. Poll /api/accounts/deviceauth/token │
  │    → authorization_code, code_verifier │
  └───────────────────┬────────────────────┘
                      │
       ▼
  ┌────────────────────────────────────────┐
  │ 4. Exchange for tokens                  │
  │    POST /oauth/token                    │
  │    → access_token (JWT), refresh_token  │
  └───────────────────┬────────────────────┘
                      │
       ▼
  ┌────────────────────────────────────────┐
  │ 5. Store to ~/.hermes/auth.json         │
  │    (NOT ~/.codex/auth.json)             │
  │    Hermes maintains its own session     │
  └────────────────────────────────────────┘
```

**Important Notes:**
- Hermes stores Codex tokens in its **own** auth store, not `~/.codex/`
- This avoids token rotation conflicts with Codex CLI / VS Code
- On first run, Hermes can **migrate** tokens from `~/.codex/auth.json`
- Access token is a JWT; expiry checked via `exp` claim

**Code References:**
- `auth.py:840-1010` — `_codex_device_code_login()`, `_refresh_codex_auth_tokens()`
- `auth.py:1015-1085` — `resolve_codex_runtime_credentials()`
- `codex_models.py` — Model discovery from Codex API

---

### 3.3 Z.AI / GLM (API Key)

**Provider ID:** `zai`  
**Auth Type:** `api_key`

**Env Vars (checked in order):**
1. `GLM_API_KEY`
2. `ZAI_API_KEY`
3. `Z_AI_API_KEY`

**Base URL Override:** `GLM_BASE_URL`

**Endpoint Auto-Detection:**

Hermes probes multiple Z.AI endpoints to find one that accepts the API key:

| Endpoint ID      | Base URL                                          | Default Model |
|------------------|---------------------------------------------------|---------------|
| `global`         | `https://api.z.ai/api/paas/v4`                    | `glm-5`       |
| `cn`             | `https://open.bigmodel.cn/api/paas/v4`            | `glm-5`       |
| `coding-global`  | `https://api.z.ai/api/coding/paas/v4`             | `glm-4.7`     |
| `coding-cn`      | `https://open.bigmodel.cn/api/coding/paas/v4`     | `glm-4.7`     |

**Code References:**
- `auth.py:350-390` — `detect_zai_endpoint()`
- `auth.py:160-175` — Provider registry entry

---

### 3.4 Kimi / Moonshot (API Key)

**Provider ID:** `kimi-coding`  
**Auth Type:** `api_key`

**Env Var:** `KIMI_API_KEY`

**Base URL Auto-Detection:**

| Key Prefix    | Base URL                         |
|---------------|----------------------------------|
| `sk-kimi-`    | `https://api.kimi.com/coding/v1` |
| (default)     | `https://api.moonshot.ai/v1`     |

**Override:** `KIMI_BASE_URL`

**Code References:**
- `auth.py:305-325` — `_resolve_kimi_base_url()`
- `auth.py:176-183` — Provider registry entry

---

### 3.5 MiniMax (API Key)

**Provider ID:** `minimax` (international) or `minimax-cn` (China)  
**Auth Type:** `api_key`

| Provider      | Env Var            | Base URL                        |
|---------------|--------------------|---------------------------------|
| `minimax`     | `MINIMAX_API_KEY`  | `https://api.minimax.io/v1`     |
| `minimax-cn`  | `MINIMAX_CN_API_KEY`| `https://api.minimaxi.com/v1`   |

**Override:** `MINIMAX_BASE_URL` / `MINIMAX_CN_BASE_URL`

**Code References:**
- `auth.py:184-197` — Provider registry entries

---

### 3.6 Anthropic (API Key / OAuth)

**Provider ID:** `anthropic`  
**Auth Type:** `api_key` (with OAuth support)

**Resolution Priority:**

```
1. ANTHROPIC_TOKEN env var
2. CLAUDE_CODE_OAUTH_TOKEN env var
3. ~/.claude/.credentials.json (claudeAiOauth.accessToken)
   └── Auto-refresh if expired + refreshToken available
4. ANTHROPIC_API_KEY env var
```

**Token Types:**

| Prefix          | Auth Method           | Headers                                |
|-----------------|-----------------------|----------------------------------------|
| `sk-ant-api*`   | API key (x-api-key)   | `x-api-key: <token>`                   |
| `sk-ant-oat*`   | OAuth/setup token     | `Authorization: Bearer <token>`        |
| (JWT/other)     | Bearer auth           | `Authorization: Bearer <token>`        |

**Beta Headers:**
- All requests: `interleaved-thinking-2025-05-14`, `fine-grained-tool-streaming-2025-05-14`
- OAuth only: `claude-code-20250219`, `oauth-2025-04-20`

**Code References:**
- `agent/anthropic_adapter.py:1-100` — Token type detection, client building
- `agent/anthropic_adapter.py:101-260` — Claude Code credential resolution, refresh
- `agent/anthropic_adapter.py:261-310` — `resolve_anthropic_token()` priority chain

---

### 3.7 OpenRouter / Custom (API Key)

**Provider ID:** `openrouter` or `custom`  
**Auth Type:** `api_key` (fallback)

**Env Vars:**
- `OPENROUTER_API_KEY` (preferred for OpenRouter)
- `OPENAI_API_KEY` (fallback, or for custom endpoints)

**Base URL:**
- Default: `https://openrouter.ai/api/v1`
- Override: `OPENAI_BASE_URL` or `OPENROUTER_BASE_URL`

**Smart Key Selection:**
- If URL contains `openrouter.ai` → prefer `OPENROUTER_API_KEY`
- If custom URL → prefer `OPENAI_API_KEY`

**Custom Providers:**

Users can define custom providers in `config.yaml`:

```yaml
custom_providers:
  - name: "local-llm"
    base_url: "http://localhost:11434/v1"
    api_key: ""  # optional
```

Then use with: `hermes chat --provider custom:local-llm`

**Code References:**
- `runtime_provider.py:55-115` — `_resolve_openrouter_runtime()`, `_resolve_named_custom_runtime()`
- `auth.py:775-830` — `resolve_provider()` priority chain

---

## 4. Token Lifecycle

### 4.1 Storage Locations

| Secret Type           | Location                      | Permissions |
|-----------------------|-------------------------------|-------------|
| OAuth tokens          | `~/.hermes/auth.json`         | `0600`      |
| API keys              | `~/.hermes/.env`              | `0600`      |
| Claude Code OAuth     | `~/.claude/.credentials.json` | `0600`      |
| Codex CLI OAuth       | `~/.codex/auth.json`          | (external)  |

### 4.2 Token Refresh

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TOKEN REFRESH MECHANISMS                              │
└─────────────────────────────────────────────────────────────────────────┘

Provider         │ Refresh Mechanism              │ Trigger
─────────────────┼────────────────────────────────┼─────────────────────
Nous Portal      │ refresh_token grant            │ expires_at < now+2m
                 │ → new access_token             │
                 │ → may rotate refresh_token     │
─────────────────┼────────────────────────────────┼─────────────────────
Nous Agent Key   │ Re-mint via agent-key endpoint │ expires_at < now+30m
                 │ (uses valid access_token)      │
─────────────────┼────────────────────────────────┼─────────────────────
Codex            │ refresh_token grant            │ JWT exp < now+2m
                 │ → new access_token (JWT)       │
                 │ → may rotate refresh_token     │
─────────────────┼────────────────────────────────┼─────────────────────
Anthropic OAuth  │ Claude Code refresh endpoint   │ expiresAt < now
                 │ (only if refreshToken exists)  │
─────────────────┼────────────────────────────────┼─────────────────────
API Key providers│ None (static keys)             │ N/A
```

### 4.3 Expiry Handling

**Nous Portal:**
- Access token: ~1 hour TTL, refresh 2 minutes before expiry
- Agent key: 30+ minute TTL, re-mint 30 minutes before expiry
- On refresh failure with `invalid_grant`: `relogin_required=True`

**Codex:**
- Access token: JWT with `exp` claim, refresh 2 minutes before expiry
- On refresh failure with `invalid_grant`/`invalid_token`: `relogin_required=True`

**Anthropic (Claude Code):**
- `expiresAt` in milliseconds since epoch
- Refresh via `https://console.anthropic.com/v1/oauth/token`
- Client ID: `9d1c250a-e61b-44d9-88ed-5944d1962f5e`

### 4.4 Error Handling

```python
class AuthError(RuntimeError):
    message: str
    provider: str
    code: Optional[str]  # "invalid_grant", "subscription_required", etc.
    relogin_required: bool
```

**Common Error Codes:**

| Code                     | Meaning                         | Action              |
|--------------------------|---------------------------------|---------------------|
| `invalid_grant`          | Refresh token expired/revoked   | Re-login required   |
| `invalid_token`          | Access token invalid            | Refresh or re-login |
| `subscription_required`  | No Nous subscription            | User action needed  |
| `insufficient_credits`   | Credits exhausted               | User action needed  |
| `temporarily_unavailable`| Rate limited                    | Retry later         |

---

## 5. Code References

### Core Auth Files

| File                              | Purpose                                       | Key Functions |
|-----------------------------------|-----------------------------------------------|---------------|
| `hermes_cli/auth.py`              | Main auth system (79KB)                       | `resolve_provider()`, `resolve_nous_runtime_credentials()`, `resolve_codex_runtime_credentials()`, `login_command()`, `logout_command()` |
| `hermes_cli/runtime_provider.py`  | Runtime credential resolution                 | `resolve_runtime_provider()`, `_resolve_openrouter_runtime()` |
| `hermes_cli/config.py`            | Config + env management                       | `save_env_value()`, `get_env_value()`, `load_config()` |
| `hermes_cli/models.py`            | Model catalogs + provider:model parsing       | `parse_model_input()`, `provider_model_ids()` |
| `hermes_cli/main.py`              | CLI entry point                               | `_model_flow_nous()`, `_model_flow_codex()`, `_model_flow_api_key_provider()` |
| `agent/anthropic_adapter.py`      | Anthropic-specific auth + API adapter         | `resolve_anthropic_token()`, `build_anthropic_client()` |
| `acp_adapter/auth.py`             | ACP server provider detection                 | `detect_provider()` |

### Key Functions by Line

**auth.py:**
```
L100-200   ProviderConfig dataclass, PROVIDER_REGISTRY
L265-350   Auth store persistence (_load_auth_store, _save_auth_store)
L380-420   Provider resolution (resolve_provider)
L500-600   OAuth device code flow (_request_device_code, _poll_for_token)
L605-700   Nous token refresh + agent key minting
L715-780   Nous runtime credential resolution
L840-1010  Codex OAuth flow + token refresh
L1015-1085 Codex runtime credential resolution
L1090-1160 API key provider resolution
L1170-1260 Status helpers (get_auth_status)
L1340-1500 Login commands (_login_nous, _login_openai_codex)
L1625-1780 resolve_nous_runtime_credentials
```

**runtime_provider.py:**
```
L25-55     resolve_requested_provider()
L58-100    Custom provider resolution
L105-145   OpenRouter/custom runtime resolution
L150-230   resolve_runtime_provider() (main entry)
```

**anthropic_adapter.py:**
```
L35-80     Token type detection (_is_oauth_token)
L85-120    Claude Code credential reading
L125-180   Token refresh logic
L185-230   resolve_anthropic_token() priority chain
L265-340   OAuth setup-token flow
```

---

## 6. Implications for Nix

### 6.1 What Can Be Declarative

| Component          | Declarative? | Notes                                          |
|--------------------|--------------|------------------------------------------------|
| Config structure   | ✅ Yes        | `config.yaml` can be generated                 |
| Default model      | ✅ Yes        | Set in config.yaml                             |
| Toolsets           | ✅ Yes        | List in config.yaml                            |
| Custom providers   | ✅ Yes        | Define in config.yaml                          |
| Display settings   | ✅ Yes        | All in config.yaml                             |
| Terminal backend   | ✅ Yes        | local/docker/singularity/ssh                   |

### 6.2 What Requires Runtime Interaction

| Component                | Interactive? | Why                                          |
|--------------------------|--------------|----------------------------------------------|
| Nous Portal OAuth        | ✅ Yes        | Requires browser-based device code auth      |
| Codex OAuth              | ✅ Yes        | Requires browser-based device code auth      |
| Anthropic OAuth          | ✅ Yes        | Requires `claude setup-token` or browser     |
| API Keys (first-time)    | ⚠️ Semi       | Can be env vars, but setup wizard helps      |
| Model selection          | ⚠️ Semi       | Can be declarative, but wizard discovers live models |

### 6.3 Nix Module Design Recommendations

```nix
# Example NixOS module options
services.hermes = {
  enable = true;
  
  # Declarative config
  config = {
    model = {
      default = "anthropic/claude-opus-4.6";
      provider = "auto";  # or "nous", "openrouter", "zai", etc.
    };
    
    terminal = {
      backend = "local";
      timeout = 180;
    };
    
    display = {
      compact = true;
      personality = "kawaii";
    };
  };
  
  # Environment variables (secrets)
  environmentFile = "/run/secrets/hermes.env";
  # OR individual secrets via sops-nix, agenix, etc.
  
  # Custom providers
  customProviders = [
    {
      name = "local-vllm";
      baseUrl = "http://localhost:8000/v1";
    }
  ];
};

# Secrets file format (hermes.env):
# OPENROUTER_API_KEY=sk-or-...
# GLM_API_KEY=...
# ANTHROPIC_API_KEY=sk-ant-api-...
```

### 6.4 Auth State Management

**For Nix deployments:**

1. **API Key Providers** (recommended for servers):
   - Use `environmentFile` with secrets management
   - Keys: `OPENROUTER_API_KEY`, `GLM_API_KEY`, `ANTHROPIC_API_KEY`, etc.
   - No interactive auth required

2. **OAuth Providers** (not recommended for headless):
   - `auth.json` must be provisioned after first login
   - Could use `systemd-tmpfiles` to pre-seed, but tokens expire
   - Better: use API key providers for automated setups

3. **Anthropic via Claude Code**:
   - Can use `~/.claude/.credentials.json` if pre-provisioned
   - Or set `ANTHROPIC_API_KEY` for API key mode

### 6.5 File Locations for Nix

```nix
# Hermes home directory
environment.variables.HERMES_HOME = "/var/lib/hermes";

# Or per-user
users.users.myuser.home = "/home/myuser";
# HERMES_HOME defaults to ~/.hermes
```

**Required directories:**
- `$HERMES_HOME/` (root)
- `$HERMES_HOME/cron/`
- `$HERMES_HOME/sessions/`
- `$HERMES_HOME/logs/`
- `$HERMES_HOME/memories/`

---

## 7. Summary

Hermes uses a sophisticated multi-provider auth system with:

1. **OAuth Device Code Flow** for Nous Portal and Codex — interactive browser-based auth with automatic token refresh
2. **API Key Resolution** for OpenRouter, Z.AI, Kimi, MiniMax, Anthropic — environment variable based with smart fallbacks
3. **Unified Credential Resolution** via `resolve_runtime_provider()` — single entry point for all providers
4. **Cross-Process Safety** with file locking and atomic writes to `auth.json`
5. **Automatic Token Refresh** for OAuth providers with configurable skew
6. **Graceful Error Handling** with user-friendly messages and `relogin_required` hints

For Nix packaging:
- API key providers are fully declarative
- OAuth providers require one-time interactive login
- Config can be fully declarative via YAML
- Secrets should use Nix secrets management (sops-nix, agenix, etc.)
