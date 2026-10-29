---
title: Container
weight: 4
---

`agent-run` startet Claude Code in einem Container, dessen einzige GitHub-Zugangsdaten ein
Agent-Token für ein Repository sind. Ihre SSH-Schlüssel, Ihr `gh`-Login, Ihre git-Konfiguration und
das Login-Token des Brokers bleiben auf Ihrem Rechner.

## Bevor Sie beginnen {#before-you-start}

* `podman`, `curl`, `jq` und `git` auf dem Rechner.
* `agent-token` in Ihrem `PATH` ([Homebrew](../homebrew/) oder [Installationsskript](../install-script/)).
* Ein Klon des [token-broker-Repositorys](https://github.com/pflege-de-labs/token-broker), das
  `agent-run` und die Image-Definition in `container/` enthält.

## Image bauen {#build-the-image}

```sh
podman build -t localhost/agent-sandbox:latest container/
```

## Konfigurieren {#configure}

```sh
export TOKEN_BROKER_URL=https://<broker>
export AGENT_APP_SLUG=<agent app slug>
export CLAUDE_CODE_OAUTH_TOKEN=<from `claude setup-token`>   # or ANTHROPIC_API_KEY
```

## Starten {#run}

Aus einem Checkout heraus (ein Klon oder ein git Worktree):

```sh
/path/to/token-broker/agent-run                 # repository from the `origin` remote
/path/to/token-broker/agent-run my-org/my-repo  # explicit repository
/path/to/token-broker/agent-run -p "fix the failing test"   # arguments go to claude
```

`agent-run`:

* holt mit `agent-token` ein Agent-Token (beim ersten Mal per Device Flow) und erneuert es alle 45
  Minuten, solange die Sitzung läuft; der Container liest es aus einer schreibgeschützten Datei;
* bindet den Checkout unter demselben Pfad ein, dazu das `.git` des Haupt-Repositorys für
  Worktrees;
* schreibt GitHub-SSH-Remotes auf HTTPS um, damit git mit dem Agent-Token pusht;
* setzt die Commit-Identität auf
  `<app>[bot] <<bot user ID>+<app>[bot]@users.noreply.github.com>`;
* hält die Einstellungen von Claude Code im benannten Volume `agent-claude`;
* bildet Ihren Benutzer auf den Container-Benutzer ab, damit Dateien Ihnen gehören;
* installiert vor dem Start von Claude die Toolchain des Repositorys aus `mise.toml` oder
  `.tool-versions`.

`AGENT_IMAGE` wählt ein anderes Image. `AGENT_PODMAN_ARGS` ergänzt podman-Flags, zum Beispiel
`--entrypoint sh` für eine Shell statt Claude.

## Toolchains {#toolchains}

Das Image enthält nur, was jedes Repository braucht: git, `gh`, `jq`, `curl`, `make`, `unzip`,
ripgrep, shellcheck, python3 und [mise](https://mise.jdx.dev). Alles andere kommt aus der
mise-Konfiguration des Repositorys, in den dort festgelegten Versionen. Installationen und Caches
liegen in den Volumes `agent-mise` und `agent-cache`, daher lädt nur die erste Sitzung je Version
herunter. Ein Repository ohne mise-Konfiguration bekommt keine zusätzlichen Tools.

`agent-run` vertraut nur der mise-Konfiguration des eingebundenen Checkouts. Ein fehlgeschlagenes
`mise install` gibt eine Warnung aus, und Claude startet trotzdem.

{{< callout type="warning" >}}
Binden Sie nie Cloud-Zugangsdaten (`~/.aws`, Kubeconfigs) ein: Es sind Entwickler-Zugangsdaten.
Lassen Sie den Agenten Code schreiben und `terraform plan` stattdessen in der CI ausführen.
{{< /callout >}}

## Grenzen {#limits}

* Das Token gilt für ein Repository: Der Abruf privater Abhängigkeiten aus anderen Repositories,
  etwa Go-Modulen, schlägt fehl.
* Commits sind unsigniert; mergen Sie Agent-Pull-Requests mit Squash.
* Nach 8 Stunden läuft das Login-Token ab, und die nächste Erneuerung gibt einen Device-Code im
  Terminal aus.
