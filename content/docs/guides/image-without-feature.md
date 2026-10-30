---
title: Use the scripts in your own image
weight: 5
---

If you cannot use the [Dev Container Feature](../../getting-started/devcontainer/), install the
client scripts in your image yourself.

## What the image needs

* `bash`, `curl`, `jq`, `git`, `gh`; `github-mcp-server` only for the MCP server.
* The scripts in `/usr/local/bin`, with `agent-gh` installed **as `gh`**. It must come before the
  real `gh` in `PATH`; the wrapper finds the real one itself.
* `TOKEN_BROKER_URL` in the environment.
* System git config:

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

* A volume for `~/.cache/agent-token`, so the login survives container restarts. It holds the
  developer's login token (8 hours) and agent tokens (1 hour); keep it per developer, never
  shared.

The agent should act only as the agent app, so the wrapper refuses `gh auth login`, `refresh` and
`setup-git`. Outside a checkout, `gh auth status` reports the agent-token login. Commands without
one target repository (`gh api orgs/...`) get no agent token and fail unauthenticated, by design.

## Install a pinned release

Check the tarball against its sha256 from the release's `checksums.txt`:

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

Debian's `gh` lands in `/usr/bin`, after `/usr/local/bin` in `PATH`. Add Claude Code and your
toolchain as usual.

## Build, run, log in

```sh
podman build -t agent-dev .
podman volume create agent-token-cache
podman run -it --name agent-dev \
  -v agent-token-cache:/root/.cache/agent-token \
  -v "$PWD":/work -w /work agent-dev bash
# inside, once per 8h:
agent-token --login
```

From another terminal: `podman exec -it agent-dev agent-token --login`.
