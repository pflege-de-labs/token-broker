# Agent tokens in containers

A coding agent in a container gets agent tokens on demand, per repo, at the moment git, gh or the
GitHub MCP server need one. Nothing is fetched at session start: agent tokens live 1h and cover
one repo, while sessions run longer and touch several repos.

| Script | Role |
|---|---|
| `agent-token` | Device-flow login (`--login`), login check (`--check`), token per repo with a cache |
| `agent-token-git-credential` | git credential helper for `github.com` |
| `agent-gh` | Wrapper installed as `gh`; sets `GH_TOKEN` for the target repo |
| `agent-github-mcp` | Starts the local `github-mcp-server` with a token for the current repo (optional) |

The developer logs in once per 8h with `agent-token --login` in an interactive terminal. All other
calls set `AGENT_TOKEN_NONINTERACTIVE=1` and fail with `run: agent-token --login` instead of
waiting for a device code nobody sees.

## What the image needs

- `bash`, `curl`, `jq`, `git`, `gh`; `github-mcp-server` only for the MCP server.
- The four scripts in `/usr/local/bin`, with `agent-gh` installed **as `gh`**. It must come
  before the real `gh` in `PATH`; the wrapper finds the real one itself.
- Environment: `TOKEN_BROKER_URL` (internal broker URL) and `LOGIN_APP_CLIENT_ID`
  (client ID of `pflege-de-agent-login`).
- System git config:

  ```sh
  # The empty value drops inherited helpers (store, osxkeychain, gh) for github.com.
  git config --system credential.https://github.com.helper ''
  git config --system --add credential.https://github.com.helper '!agent-token-git-credential'
  # Without the path git cannot say which repo it needs a token for.
  git config --system credential.https://github.com.useHttpPath true
  # Credential helpers only work over HTTPS.
  git config --system url.https://github.com/.insteadOf git@github.com:
  ```

- A volume for `~/.cache/agent-token`, so the login survives container restarts. It holds the
  developer's login token (8h) and agent tokens (1h); keep it per developer, never shared.

Do not run `gh auth login` or `gh auth setup-git` in the container: the agent should act only as
`pflege-de-agent`. Commands without one target repo (`gh api orgs/...`) get no agent token and fail
unauthenticated, by design.

The scripts are not published as a package. Copy them into the image build context at a pinned
token-broker commit, e.g. `.devcontainer/agent-bin/`.

## Plain container

`Containerfile`:

```dockerfile
FROM docker.io/library/debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl git gh jq \
 && rm -rf /var/lib/apt/lists/*
COPY agent-bin/agent-token agent-bin/agent-token-git-credential agent-bin/agent-github-mcp /usr/local/bin/
COPY agent-bin/agent-gh /usr/local/bin/gh
RUN git config --system credential.https://github.com.helper '' \
 && git config --system --add credential.https://github.com.helper '!agent-token-git-credential' \
 && git config --system credential.https://github.com.useHttpPath true \
 && git config --system url.https://github.com/.insteadOf git@github.com:
ENV TOKEN_BROKER_URL=https://token-broker.internal \
    LOGIN_APP_CLIENT_ID=<login app client ID>
```

Debian's `gh` lands in `/usr/bin`, after `/usr/local/bin` in `PATH`. Add Claude Code and your
toolchain as usual.

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

## Devcontainer

`.devcontainer/devcontainer.json`, next to a `Dockerfile` like the one above (without the `ENV`
line):

```jsonc
{
  "build": { "dockerfile": "Dockerfile" },
  "containerEnv": {
    "TOKEN_BROKER_URL": "https://token-broker.internal",
    "LOGIN_APP_CLIENT_ID": "<login app client ID>"
  },
  "mounts": [
    // Per developer and per devcontainer; survives rebuilds.
    "source=agent-token-cache-${devcontainerId},target=/home/vscode/.cache/agent-token,type=volume"
  ],
  "remoteUser": "vscode",
  // A fresh volume is owned by root.
  "postCreateCommand": "sudo chown vscode: /home/vscode/.cache/agent-token",
  // Prompts in the terminal that opens on attach; skipped while the login is still valid.
  "postAttachCommand": "agent-token --check 2>/dev/null || agent-token --login"
}
```

Adjust the home path to `remoteUser`. If the container user's home differs from the mount
target, `agent-token` caches elsewhere and logs in on every rebuild.

## Claude Code in the container

A SessionStart hook reminds the agent (and so you) when the login is missing. It only checks;
it never starts a login. `~/.claude/settings.json` in the container:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "agent-token --check 2>&1 || true" }] }
    ]
  }
}
```

The output lands in Claude's context; log in with `! agent-token --login`.

### GitHub MCP server

The hosted GitHub MCP server and the claude.ai GitHub connector use your own identity, not the
agent's. Disable them in the container and run `github-mcp-server` locally instead:

```sh
claude mcp add --scope user github -- agent-github-mcp --toolsets repos,issues,pull_requests
```

`agent-github-mcp` takes the repo from the `origin` remote of the directory Claude Code starts in.
Limits:

- The token is fixed for the server process: after 1h calls fail with 401. Reconnect via `/mcp`.
- One repo per server. Work on another repo needs a Claude Code session started there.
- Installation tokens cannot call user endpoints, so tools like `get_me` fail.
