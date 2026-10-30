---
title: Installationsskript
weight: 3
---

Installieren Sie die Client-Skripte aus einem Release-Tarball, ohne Paketmanager.

```sh
curl -fsSL https://raw.githubusercontent.com/pflege-de-labs/token-broker/main/scripts/install.sh | bash
```

Das Skript:

* lädt `agent-token-<version>.tar.gz` aus dem Release und prüft dessen sha256 gegen die
  `checksums.txt` des Releases;
* installiert die Skripte nach `$PREFIX/bin`, wobei `PREFIX` standardmäßig `~/.local` ist;
* installiert `agent-gh` als `agent-gh`, nie als `gh` auf Ihrem Rechner;
* ändert nie Ihre globale git-Konfiguration.

Stellen Sie sicher, dass `$PREFIX/bin` in Ihrem `PATH` liegt.

## Version festlegen {#pin-a-version}

```sh
curl -fsSL https://raw.githubusercontent.com/pflege-de-labs/token-broker/main/scripts/install.sh \
  | bash -s -- --version v0.7.0
```

## Installationsverzeichnis wählen {#choose-the-install-directory}

```sh
curl -fsSL https://raw.githubusercontent.com/pflege-de-labs/token-broker/main/scripts/install.sh \
  | PREFIX=/opt/agent bash
```

Jedes `v*`-Release enthält `agent-token-<version>.tar.gz` (die Skripte in `bin/`) und
`checksums.txt`. Das Skript braucht `bash`, `curl` und `jq`; `gh` wird für `agent-gh` gebraucht.
