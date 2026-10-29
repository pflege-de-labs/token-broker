---
title: Client-Umgebung
weight: 2
---

Variablen, die die Client-Skripte und `agent-run` lesen.

| Variable | Gelesen von | Bedeutung |
| --- | --- | --- |
| `TOKEN_BROKER_URL` | `agent-token` und die darauf aufbauenden Skripte | Broker-URL. Pflicht. |
| `LOGIN_APP_CLIENT_ID` | `agent-token` | Überschreibt die Client-ID der Login-App, die der Broker unter `/login-app` liefert. |
| `AGENT_TOKEN_NONINTERACTIVE` | `agent-token` | `1` scheitert, statt einen Device Flow zu starten. Wird von den übrigen Skripten gesetzt. |
| `XDG_CACHE_HOME` | `agent-token`, `agent-run` | Basis des Cache-Verzeichnisses; Standard `~/.cache`. Der Cache ist `<base>/agent-token`. |
| `AGENT_COMMIT_MODE` | `agent-commit` | `local` führt ein einfaches `git commit` aus; Standard `api`. |
| `GH_REPO` | `agent-gh` | Ziel-Repository, wie bei `gh`. |
| `AGENT_APP_SLUG` | `agent-run` | Slug der Agent-App. Pflicht. |
| `AGENT_IMAGE` | `agent-run` | Zu startendes Image; Standard `localhost/agent-sandbox:latest`. |
| `AGENT_PODMAN_ARGS` | `agent-run` | Zusätzliche Flags für `podman run`. |
| `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY` | `agent-run` | Werden für die Authentifizierung von Claude Code in den Container übergeben. |

## Woher die Broker-URL kommt {#where-the-broker-url-comes-from}

* Claude-Code-Plugin: `TOKEN_BROKER_URL`, sonst die Plugin-Option `broker_url`, sonst die
  Actions-Variable `AGENT_TOKEN_BROKER_URL` der Organisation (nie des Repositorys), gelesen mit
  Ihrem `gh`.
* Dev Container: `AGENT_TOKEN_BROKER_URL` und `AGENT_LOGIN_CLIENT_ID` werden auf dem Rechner gelesen
  und als `TOKEN_BROKER_URL` und `LOGIN_APP_CLIENT_ID` übergeben; siehe
  [Dev Container](../../getting-started/devcontainer/).
* Alles andere: Setzen Sie `TOKEN_BROKER_URL` selbst.
