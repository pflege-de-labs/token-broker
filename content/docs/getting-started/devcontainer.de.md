---
title: Dev Container
weight: 5
---

Das Dev Container Feature `agent-token` installiert die Client-Skripte, auf ein Release festgelegt,
in einen Devcontainer. Es wird in
[pflege-de-labs/devcontainer-features](https://github.com/pflege-de-labs/devcontainer-features#agent-token)
veröffentlicht.

Das
[`.devcontainer/`](https://github.com/pflege-de-labs/token-broker/tree/main/.devcontainer) des
token-broker-Repositorys ist ein funktionierendes Setup zum Kopieren. Es:

* installiert die Skripte mit dem Feature (in `devcontainer.json` per Digest festgelegt);
* setzt die Bot-Identität und installiert Claude Code sowie die Toolchain aus `mise.toml`;
* ergänzt einen SessionStart-Hook als Managed Settings, der erinnert, wenn der Login fehlt;
* begrenzt ausgehenden Verkehr mit einer Egress-Firewall auf eine Positivliste von Domains plus den
  Broker-Host.

Beim ersten Verbinden zeigt das Terminal einen Device-Code; melden Sie sich dort an. Mit Podman
setzen Sie `"dev.containers.dockerPath": "podman"` in Ihren VS-Code-Einstellungen.

## Broker-URL und Login-App {#broker-url-and-login-app}

Zwei Actions-Variablen liefern die Broker-URL und die Client-ID der Login-App, nicht das
Repository:

| Variable | Umgebung im Container |
| --- | --- |
| `AGENT_TOKEN_BROKER_URL` | `TOKEN_BROKER_URL` |
| `AGENT_LOGIN_CLIENT_ID` | `LOGIN_APP_CLIENT_ID` |

Eine Repository-Variable gleichen Namens überschreibt den Wert der Organisation. Im Container kann
nichts Variablen lesen, deshalb läuft
[`broker-env.sh`](https://github.com/pflege-de-labs/token-broker/blob/main/.devcontainer/broker-env.sh)
als `initializeCommand` auf dem Rechner. Es braucht `gh` (angemeldet, Scope `repo`) und `jq`, liest
beide Variablen für das `origin`-Repository und schreibt `.devcontainer/.env`, das `runArgs` mit
`--env-file` übergibt:

```jsonc
{
  "initializeCommand": ".devcontainer/broker-env.sh",
  "runArgs": ["--env-file=${localWorkspaceFolder}/.devcontainer/.env"]
}
```

## Gut zu wissen {#things-to-know}

* Alles, was im Container committet oder gepusht wird, geht als Bot der Agent-App hinaus, auch
  Commits aus der Source-Control-Ansicht von VS Code. Committen Sie als Sie selbst auf dem Rechner.
* Der Agent committet mit [`agent-commit`](../../guides/signed-commits/), damit Branches, die
  Signaturen verlangen, die Commits akzeptieren.
* VS Code leitet Ihre Zugangsdaten in Devcontainer weiter. Das Setup schaltet
  `git.terminalAuthentication` und `github.gitAuthentication` ab, überschreibt `GIT_AUTHOR_*` und
  `GIT_COMMITTER_*` und lässt den Credential-Helper `quit=1` antworten, wenn er kein Token hat. Ihr
  SSH-Agent wird weiterhin weitergeleitet: Die Firewall blockiert Port 22, aber er kann noch
  signieren. Für volle Isolation nutzen Sie [`agent-run`](../container/).
* Ein git Worktree funktioniert nicht als Workspace, weil sein `.git` außerhalb des Mounts zeigt.
  Öffnen Sie einen Klon.
* Netzwerkzugriff über die Positivliste hinaus braucht eine Änderung an `allowed-domains` und einen
  Rebuild.

Für ein Image ohne das Feature siehe
[Die Skripte im eigenen Image nutzen](../../guides/image-without-feature/). Für den GitHub-MCP-Server
siehe [`agent-github-mcp`](../../reference/client-cli/#agent-github-mcp).
