---
title: Client-Befehle
weight: 1
---

Die Client-Skripte liegen in `bin/` jedes Release-Assets `agent-token-<version>.tar.gz` und des
Claude-Code-Plugins. Sie brauchen `bash`, `curl` und `jq`. Alle lesen die
[Client-Umgebung](../client-env/).

| Skript | Aufgabe |
| --- | --- |
| `agent-token` | Device-Flow-Login, Login-Prüfung, Token je Repository mit Cache |
| `agent-token-git-credential` | git-Credential-Helper für `github.com` |
| `agent-gh` | Wrapper für `gh`, der `GH_TOKEN` für das Ziel-Repository setzt |
| `agent-github-mcp` | Startet den lokalen `github-mcp-server` mit einem Token für das aktuelle Repository |
| `agent-commit` | Committet die gestageten Änderungen über die GitHub-API, sodass GitHub sie signiert |

## `agent-token` {#agent-token}

```text
agent-token org/repo                  prints a 1h agent token for that repository
agent-token --login                   logs in via the login app's device flow (interactive)
agent-token --check                   exits 1 unless a login is cached
agent-token --permissions org/repo    prints the permissions GitHub granted that token (JSON)
agent-token --version                 prints the version (from v0.7.0)
```

Das Login-Token wird 8 Stunden in `~/.cache/agent-token/login.json` (Modus 600) zwischengespeichert.
Ein Token je Repository wird wiederverwendet, bis es in 5 Minuten abläuft. Braucht
`TOKEN_BROKER_URL`. Die Client-ID der Login-App kommt vom Broker (`GET /login-app`);
`LOGIN_APP_CLIENT_ID` überschreibt sie.

Alle Aufrufe außer `--login` setzen `AGENT_TOKEN_NONINTERACTIVE=1` und scheitern mit
`run: agent-token --login`, statt auf einen Device-Code zu warten, den niemand sieht.

## `agent-token-git-credential` {#agent-token-git-credential}

Ein git-Credential-Helper, der Anfragen für `github.com` mit einem Agent-Token für das angefragte
Repository beantwortet und für andere Hosts schweigt. Hat er kein Token, antwortet er `quit=1`,
damit kein späterer Helper an seiner Stelle antwortet. Er braucht `credential.useHttpPath=true`,
sonst sendet git keinen Pfad. Die System-git-Konfiguration steht unter
[Die Skripte im eigenen Image nutzen](../../guides/image-without-feature/).

## `agent-gh` {#agent-gh}

Führt das echte `gh` mit `GH_TOKEN` als Agent-Token für das Ziel-Repository aus. Das Ziel ist das
Flag `--repo`/`-R`, sonst `GH_REPO`, sonst der Remote `origin`. Installieren Sie es in Containern
als `gh`, im `PATH` vor dem echten `gh`; auf dem Rechner installiert das Installationsskript es als
`agent-gh`.

* `gh auth login`, `refresh` und `setup-git` werden verweigert.
* Außerhalb eines Checkouts meldet `gh auth status` den agent-token-Login.
* Befehle ohne ein einzelnes Ziel-Repository (`gh api orgs/...`) bekommen kein Agent-Token und
  laufen mit der eigenen Authentifizierung von `gh`, falls vorhanden.

## `agent-github-mcp` {#agent-github-mcp}

Startet `github-mcp-server stdio` mit einem Agent-Token für das `origin`-Repository des aktuellen
Verzeichnisses; weitere Argumente gehen an den Server. Registrieren Sie es bei Claude Code:

```sh
claude mcp add --scope user github -- agent-github-mcp --toolsets repos,issues,pull_requests
```

* Das Token steht für die Lebensdauer des Serverprozesses fest: Nach 1 Stunde schlagen Aufrufe mit
  401 fehl. Verbinden Sie sich über `/mcp` neu.
* Ein Repository je Server. Für ein anderes Repository brauchen Sie eine dort gestartete Sitzung.
* Installation-Tokens können keine User-Endpunkte aufrufen, daher scheitern Tools wie `get_me`.

Der gehostete GitHub-MCP-Server und der claude.ai-GitHub-Connector nutzen Ihre eigene Identität,
nicht die des Agenten.

## `agent-commit` {#agent-commit}

```text
agent-commit -m <message> [-m <paragraph>]...
agent-commit -F <file>
```

Committet die gestageten Änderungen über GraphQL `createCommitOnBranch`, sodass GitHub den Commit
signiert, pusht ihn und setzt den lokalen Branch darauf. Details und Grenzen:
[Agent-Commits signieren](../../guides/signed-commits/). `AGENT_COMMIT_MODE=local` führt stattdessen
ein einfaches `git commit` mit den Argumenten aus.
