---
title: Die Skripte im eigenen Image nutzen
weight: 5
---

Wenn Sie das [Dev Container Feature](../../getting-started/devcontainer/) nicht nutzen können,
installieren Sie die Client-Skripte selbst in Ihrem Image.

## Was das Image braucht {#what-the-image-needs}

* `bash`, `curl`, `jq`, `git`, `gh`; `github-mcp-server` nur für den MCP-Server.
* Die Skripte in `/usr/local/bin`, mit `agent-gh` **als `gh`** installiert. Es muss im `PATH` vor
  dem echten `gh` stehen; der Wrapper findet das echte selbst.
* `TOKEN_BROKER_URL` in der Umgebung.
* Die System-git-Konfiguration:

  ```sh
  # The empty value drops inherited helpers (store, osxkeychain, gh) for github.com.
  git config --system credential.https://github.com.helper ''
  git config --system --add credential.https://github.com.helper '!agent-token-git-credential'
  # Without the path git cannot say which repo it needs a token for.
  git config --system credential.https://github.com.useHttpPath true
  # Credential helpers only work over HTTPS.
  git config --system url.https://github.com/.insteadOf git@github.com:
  git config --system --add url.https://github.com/.insteadOf ssh://git@github.com/
  ```

* Ein Volume für `~/.cache/agent-token`, damit der Login Container-Neustarts übersteht. Es enthält
  das Login-Token des Entwicklers (8 Stunden) und Agent-Tokens (1 Stunde); halten Sie es pro
  Entwickler getrennt und teilen Sie es nie.

Der Agent soll nur als Agent-App handeln, daher verweigert der Wrapper `gh auth login`, `refresh`
und `setup-git`. Außerhalb eines Checkouts meldet `gh auth status` den agent-token-Login. Befehle
ohne ein einzelnes Ziel-Repository (`gh api orgs/...`) bekommen kein Agent-Token und schlagen
absichtlich unauthentifiziert fehl.

## Ein festgelegtes Release installieren {#install-a-pinned-release}

Prüfen Sie den Tarball gegen sein sha256 aus der `checksums.txt` des Releases:

```dockerfile
FROM docker.io/library/debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl git gh jq \
 && rm -rf /var/lib/apt/lists/*
ARG AGENT_TOKEN_VERSION=<release, e.g. 0.7.0>
ARG AGENT_TOKEN_SHA256=<its sha256>
RUN curl -fsSL -o /tmp/agent-token.tgz \
      "https://github.com/pflege-de-labs/token-broker/releases/download/v$AGENT_TOKEN_VERSION/agent-token-$AGENT_TOKEN_VERSION.tar.gz" \
 && echo "$AGENT_TOKEN_SHA256  /tmp/agent-token.tgz" | sha256sum -c - \
 && tar -xzf /tmp/agent-token.tgz -C /tmp \
 && install -m 755 /tmp/bin/agent-token /tmp/bin/agent-token-git-credential /tmp/bin/agent-github-mcp /tmp/bin/agent-commit /usr/local/bin/ \
 && install -m 755 /tmp/bin/agent-gh /usr/local/bin/gh \
 && rm -rf /tmp/agent-token.tgz /tmp/bin
RUN git config --system credential.https://github.com.helper '' \
 && git config --system --add credential.https://github.com.helper '!agent-token-git-credential' \
 && git config --system credential.https://github.com.useHttpPath true \
 && git config --system url.https://github.com/.insteadOf git@github.com: \
 && git config --system --add url.https://github.com/.insteadOf ssh://git@github.com/
ENV TOKEN_BROKER_URL=https://<broker>
```

Das `gh` von Debian landet in `/usr/bin`, hinter `/usr/local/bin` im `PATH`. Ergänzen Sie Claude
Code und Ihre Toolchain wie gewohnt.

## Bauen, starten, anmelden {#build-run-log-in}

```sh
podman build -t agent-dev .
podman volume create agent-token-cache
podman run -it --name agent-dev \
  -v agent-token-cache:/root/.cache/agent-token \
  -v "$PWD":/work -w /work agent-dev bash
# inside, once per 8h:
agent-token --login
```

Aus einem anderen Terminal: `podman exec -it agent-dev agent-token --login`.
