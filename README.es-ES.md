# nix-hermes-agent

Paquete de Nix y módulo de NixOS declarativo para [Hermes Agent](https://github.com/NousResearch/hermes-agent) de Nous Research.

Todo está configurado en Nix. Configuración, documentos, secretos, servicio — un `nixos-rebuild switch` y ya está activo.

Los pines de upstream se promueven a través de PRs de candidatos en cuarentena, por lo que una versión defectuosa de Hermes no puede reemplazar el último paquete conocido como estable. Consulta [la política de actualización de upstream](docs/UPDATE-POLICY.md).

## Inicio Rápido

### 1. Añadir a tu flake

```nix
{
  inputs.nix-hermes.url = "github:0xrsydn/nix-hermes-agent";

  outputs = { self, nixpkgs, nix-hermes, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        nix-hermes.nixosModules.hermes-agent
        ./hermes.nix  # tu configuración (ver abajo)
      ];
    };
  };
}
```

### 2. Configurar declarativamente

```nix
# hermes.nix
{ ... }:
{
  services.hermes-agent = {
    enable = true;

    # ── Configuración declarativa (se renderiza en cli-config.yaml) ──
    config = {
      model = {
        default = "anthropic/claude-opus-4.6";
        provider = "openrouter";
      };
      terminal = {
        backend = "local";
        timeout = 180;
        lifetime_seconds = 300;
      };
      agent = {
        max_turns = 60;
        reasoning_effort = "medium";
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
        memory_char_limit = 2200;
        nudge_interval = 10;
      };
      compression = {
        enabled = true;
        threshold = 0.85;
        summary_model = "google/gemini-3-flash-preview";
      };
      toolsets = [ "all" ];
    };

    # ── Secretos (no en el Nix store) ──
    environmentFiles = [
      "/run/secrets/hermes-env"  # ANTHROPIC_API_KEY, TELEGRAM_TOKEN, etc.
    ];

    # ── Variables de entorno no secretas ──
    environment = {
      LLM_MODEL = "anthropic/claude-opus-4.6";
    };

    # ── Documentos del espacio de trabajo (en línea o rutas de archivo) ──
    documents = {
      "SOUL.md" = ''
        # SOUL.md
        Eres un asistente de IA agudo y pragmático.
      '';
      "AGENTS.md" = ''
        # AGENTS.md
        Lee SOUL.md primero. Luego ayuda al usuario.
      '';
      "USER.md" = ''
        # USER.md
        Nombre: Tu Humano
      '';
      # O referencia un archivo:
      # "SOUL.md" = ./documents/SOUL.md;
    };

    # ── Habilidades declarativas (fase 1) ──
    skills = {
      bundled.enable = true;
      optional = [
        "creative/blender-mcp"
      ];
      custom = {
        repo-watch = {
          category = "research";
          source = ./skills/repo-watch;
        };
      };
    };

    # ── Servidores MCP ──
    mcpServers = {
      context7 = {
        command = "npx";
        args = [ "-y" "@upstash/context7-mcp@latest" ];
      };
    };

    # ── Herramientas extra en el PATH ──
    extraPackages = with pkgs; [ jq ripgrep curl ];
  };
}
```

### Gestión de Secretos

#### Enfoque de archivos planos

```nix
services.hermes-agent = {
  environmentFiles = [ "/run/secrets/hermes-env" ];
  authFile = "/run/secrets/hermes-auth.json";  # opcional, para tokens OAuth
};
```

#### Enfoque con sops-nix

```nix
sops.secrets."hermes/env" = {
  sopsFile = ./secrets/hermes.yaml;
  owner = "hermes";
  group = "hermes";
};

sops.secrets."hermes/auth" = {
  sopsFile = ./secrets/hermes.yaml;
  owner = "hermes";
  group = "hermes";
};

services.hermes-agent = {
  enable = true;
  environmentFiles = [ config.sops.secrets."hermes/env".path ];
  authFile = config.sops.secrets."hermes/auth".path;
  config.model = {
    default = "anthropic/claude-opus-4.6";
    provider = "openrouter";
  };
};
```

#### Ejemplo de estructura de archivo de secretos

```yaml
hermes/env: |
    OPENROUTER_API_KEY=sk-or-...
    ANTHROPIC_API_KEY=sk-ant-...
    TELEGRAM_TOKEN=123456:ABC...
    GLM_API_KEY=...
hermes/auth: |
    {"nous": {"token": "...", "refresh": "..."}, "codex": {"token": "..."}}
```

### 3. Crear archivo de secretos

```bash
# /run/secrets/hermes-env (o donde gestiones tus secretos)
OPENROUTER_API_KEY=sk-or-...
ANTHROPIC_API_KEY=sk-ant-...
TELEGRAM_TOKEN=123456:ABC...
TELEGRAM_ALLOWED_USERS=tu_user_id
```

### 4. Desplegar

```bash
nixos-rebuild switch
systemctl status hermes-agent
journalctl -u hermes-agent -f
```

## Arquitectura

```
Tú (Telegram/Discord/WhatsApp/Slack) → Gateway → Tools → La máquina ejecuta acciones
```

### Cómo funciona

1. El `attrset` `services.hermes-agent.config` se fusiona profundamente y se renderiza en `cli-config.yaml`.
2. Los documentos se instalan en el directorio del espacio de trabajo (`workspace`).
3. Los secretos permanecen fuera del Nix store mediante `environmentFiles`.
4. El servicio de systemd ejecuta `hermes gateway` con todo conectado.

### Diseño de directorios

```
/var/lib/hermes/              # stateDir
├── .hermes/                  # Hogar de Hermes (HERMES_HOME)
│   ├── cli-config.yaml       # Generado desde la opción config
│   ├── .env                  # Secretos (desde environmentFiles)
│   ├── memory/               # Memoria del agente (tiempo de ejecución)
│   ├── skills/               # Habilidades (tiempo de ejecución)
│   └── logs/                 # Logs de sesión
├── workspace/                # workingDirectory
│   ├── SOUL.md               # Desde la opción documents
│   ├── AGENTS.md
│   └── USER.md
└── logs/
    └── gateway.log           # Log del servicio
```

## Habilidades Declarativas vs Habilidades Nativas de Hermes

La opción `skills` está diseñada para **aumentar a Hermes**, no para reemplazar el flujo de trabajo nativo de habilidades de Hermes.

Ambos enfoques se componen en el mismo directorio de ejecución:

- `${stateDir}/.hermes/skills/`

Eso significa que puedes usar ambos:

- **habilidades declarativas** desde Nix.
- **habilidades interactivas/de tiempo de ejecución** mediante `hermes skills install`.

### Modelo de propiedad

#### Gestionadas por Nix
Las habilidades declaradas a través de:

- `services.hermes-agent.skills.bundled`
- `services.hermes-agent.skills.optional`
- `services.hermes-agent.skills.custom`

son conciliadas por el módulo y rastreadas en:

- `.nix-managed-skills.json`

Estas rutas se consideran **propiedad de Nix**.

#### Gestionadas por Hermes
Las habilidades instaladas posteriormente a través de la CLI de Hermes, junto con los metadatos del hub en:

- `.hermes/skills/.hub/`

no son tocadas por el módulo **a menos que colisionen con una ruta gestionada por Nix**.

### Regla de colisión

Si una instalación de la CLI de Hermes y una habilidad declarativa de Nix apuntan a la misma ruta instalada, **la versión declarativa de Nix gana en la siguiente activación/reconstrucción**.

Ejemplo:

- Nix declara `creative/blender-mcp`.
- El usuario instala más tarde otro `creative/blender-mcp` a través de la CLI de Hermes.

En la siguiente reconstrucción, se restaura la versión declarada en Nix.

### Flujo de trabajo recomendado

Usa la **CLI de Hermes** para:

- Experimentación.
- Descubrimiento de habilidades en el hub/comunidad.
- Instalaciones temporales.
- Probar antes de conservar.

Usa las **habilidades declarativas de Nix** para:

- Despliegues estables/reproducibles.
- Habilidades de upstream empaquetadas que siempre quieras tener.
- Habilidades opcionales seleccionadas que quieras fijar a la revisión del paquete.
- Habilidades personalizadas locales almacenadas en git.

Un patrón recomendado es:

1. Instalar/probar una habilidad interactivamente.
2. Decidir que vale la pena conservarla.
3. Promoverla a la configuración de Nix si deseas que sea reproducible.

Esto mantiene `nix-hermes-agent` útil sin interferir con la experiencia nativa de Hermes.

## Opciones del Módulo

| Opción | Tipo | Predeterminado | Descripción |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Habilitar el gateway de Hermes Agent |
| `config` | attrset | `{}` | Configuración declarativa (→ cli-config.yaml) |
| `configFile` | path | `null` | Usar un archivo de configuración existente (sobrescribe `config`) |
| `documents` | attrset | `{}` | Archivos del espacio de trabajo (valores de cadena o ruta) |
| `skills` | attrset | `{}` | Habilidades declarativas de Hermes (bundled, optional, custom local) |
| `environmentFiles` | list | `[]` | Archivos de entorno para secretos (systemd EnvironmentFile) |
| `environment` | attrset | `{}` | Variables de entorno no secretas |
| `authFile` | path | `null` | Archivo de credenciales OAuth (auth.json) |
| `mcpServers` | attrset | `{}` | Configuraciones de servidor MCP (fusionadas en config) |
| `user` | string | `"hermes"` | Usuario del servicio |
| `group` | string | `"hermes"` | Grupo del servicio |
| `stateDir` | path | `/var/lib/hermes` | Directorio de estado |
| `workingDirectory` | path | `${stateDir}/workspace` | Directorio de trabajo |
| `extraPackages` | list | `[]` | Paquetes extra en el PATH |
| `extraArgs` | list | `[]` | Argumentos extra para `hermes gateway` |
| `logPath` | path | `${stateDir}/logs/gateway.log` | Archivo de log |
| `restart` | string | `"always"` | Política de reinicio de systemd |
| `restartSec` | int | `5` | Retraso de reinicio |

## Referencia de Configuración

El `attrset` `config` se mapea directamente al `cli-config.yaml` de Hermes. Secciones clave:

| Sección | Propósito |
|---------|---------|
| `model` | Modelo predeterminado, proveedor, base_url |
| `terminal` | Backend (local/ssh/docker/modal), cwd, timeout |
| `agent` | max_turns, verbose, reasoning_effort, personalities |
| `memory` | memory_enabled, user_profile_enabled, límites de caracteres |
| `compression` | Ajustes de compresión de contexto |
| `session_reset` | Política de auto-reinicio para mensajería |
| `skills` | Ajustes de sugerencia para creación de habilidades |
| `toolsets` | Qué grupos de herramientas habilitar |
| `mcp_servers` | Conexiones de servidores MCP |
| `delegation` | Ajustes de sub-agentes |
| `browser` | Ajustes de la herramienta de navegador |
| `stt` | Configuración de transcripción de voz |
| `display` | Ajustes de UI/skin |

Consulta la [referencia de configuración completa](https://raw.githubusercontent.com/NousResearch/hermes-agent/main/cli-config.yaml.example).

## Solo el Paquete

```bash
# Ejecutar directamente
nix run github:0xrsydn/nix-hermes-agent -- --help

# En un shell de desarrollo
nix develop github:0xrsydn/nix-hermes-agent

# Usar el overlay
nixpkgs.overlays = [ nix-hermes.overlays.default ];
```

## Licencia

MIT (igual que el upstream)
