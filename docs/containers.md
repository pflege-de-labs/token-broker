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

[`.devcontainer/`](../.devcontainer) is a working setup for this repository; copy it for others.
It links the scripts from the checkout, sets the broker URL, the login app and the bot identity,
installs Claude Code and the toolchain from `mise.toml`, and adds the SessionStart hook below as
managed settings. On first attach the terminal shows a device code; log in there.

With Podman, set `"dev.containers.dockerPath": "podman"` in your VS Code settings.

Everything committed or pushed in the container goes out as `pflege-de-agent[bot]`, your own
commits from the Source Control view included. Commit as yourself from the host.

VS Code forwards your credentials into devcontainers; the setup closes what it can:

- `GIT_AUTHOR_*`/`GIT_COMMITTER_*` override the host `~/.gitconfig` VS Code copies in.
- `git.terminalAuthentication` and `github.gitAuthentication` are off, so VS Code does not
  answer git with your GitHub login.
- `agent-token-git-credential` answers `quit=1` when it has no token, so no later helper (VS
  Code's forwarded one) answers for `github.com`.
- Your SSH agent is still forwarded. The firewall blocks port 22, so it cannot reach GitHub, but
  it can still sign. For full isolation use `agent-run` (see [local.md](local.md)) or the
  devcontainer CLI without VS Code.

A git worktree does not work as the workspace: its `.git` points outside the mount. Open a clone.
`CLAUDE_CODE_OAUTH_TOKEN` is passed from the host if set; otherwise run `claude` and log in. The
Claude login and settings live in a volume and survive rebuilds.

### Egress firewall

`init-firewall.sh` runs as root on every container start and limits outbound traffic to HTTPS on
the domains in [`allowed-domains`](../.devcontainer/allowed-domains) and their subdomains, plus
the broker. A local dnsmasq answers only those names and adds each resolved IP to the allowlist,
so rotating CDN addresses keep working and DNS cannot carry data out. IPv6 is blocked.

The agent cannot lift it:

- `vscode` may only run `sudo /usr/local/bin/init-firewall.sh`, without arguments. The script and
  the domain list are root-owned copies in the image, not files from the workspace.
- `containerUser` is `root`. Podman hands `--cap-add` capabilities to a non-root container user
  as ambient caps, so `vscode` could otherwise flush the rules itself. Docker does not.

Network access beyond the list needs a change to `allowed-domains` and a rebuild. `mise install`
runs before the firewall, so new tool versions also need a rebuild. Skipping permission prompts
(`claude --dangerously-skip-permissions`) is reasonable only with the firewall active: the agent
can still change anything in the workspace and reach every allowed domain.

The firewall needs the `ip_set` and `xt_set` kernel modules. The Fedora CoreOS image of
`podman machine` ships them and loads them on demand; no machine setup is needed.

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
agent's. The devcontainer disables claude.ai connectors via managed settings
(`disableClaudeAiConnectors`), and the firewall blocks the hosted server. Run
`github-mcp-server` locally instead:

```sh
claude mcp add --scope user github -- agent-github-mcp --toolsets repos,issues,pull_requests
```

`agent-github-mcp` takes the repo from the `origin` remote of the directory Claude Code starts in.
Limits:

- The token is fixed for the server process: after 1h calls fail with 401. Reconnect via `/mcp`.
- One repo per server. Work on another repo needs a Claude Code session started there.
- Installation tokens cannot call user endpoints, so tools like `get_me` fail.
