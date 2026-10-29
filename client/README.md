# Client scripts

A coding agent gets short-lived tokens of the agent GitHub App instead of the developer's
credentials. Tokens are fetched on demand, per repo, at the moment git, gh or the GitHub MCP server
need one. Agent tokens live 1h and cover one repo, while sessions run longer and touch several repos.

The scripts live in the Claude Code plugin, [`plugins/agent-token/bin`](../plugins/agent-token/bin) (ADR 15).

| Script | Role |
|---|---|
| `agent-token` | Device-flow login (`--login`), login check (`--check`), token per repo with a cache; `--permissions org/repo` prints what GitHub granted that token |
| `agent-token-git-credential` | git credential helper for `github.com` |
| `agent-gh` | `gh` wrapper; sets `GH_TOKEN` for the target repo. Installed as `gh` in containers, as `agent-gh` on the host |
| `agent-github-mcp` | Starts the local `github-mcp-server` with a token for the current repo (optional) |
| `agent-commit` | Commits the staged changes through the GitHub API, so GitHub signs them (optional) |

Every `v*` release attaches them as `agent-token-<version>.tar.gz` (`bin/` inside) with a
`checksums.txt` (ADR 14). The [agent-token devcontainer feature](https://github.com/pflege-de-labs/devcontainer-features#agent-token)
installs a pinned release; a script change reaches devcontainers with the next release and a
feature bump. On the host, the plugin tracks `main`; Homebrew and `scripts/install.sh` install a
pinned release.

The developer logs in once per 8h with `agent-token --login` in an interactive terminal. All other
calls set `AGENT_TOKEN_NONINTERACTIVE=1` and fail with `run: agent-token --login` instead of
waiting for a device code nobody sees.

Environment: `TOKEN_BROKER_URL` (internal broker URL). The login app's client ID comes from the
broker (`GET /login-app`, token-broker ≥ 0.4.0); `LOGIN_APP_CLIENT_ID` overrides it. The pflege-de
orgs publish the URL as the Actions variable `AGENT_TOKEN_BROKER_URL` (repo variables override it);
[`.devcontainer/broker-env.sh`](../.devcontainer/broker-env.sh) reads it on the host and passes it
into the container. The plugin reads only the org variable ([docs/claude-plugin.md](../docs/claude-plugin.md)).

## Signed commits

`git commit` in the container makes unsigned commits: GitHub signs app commits only when it
creates them itself. Rulesets with `required_signatures` then block them on protected branches
(squash merges still work, GitHub signs the squash commit). `agent-commit` instead sends the
staged changes to GraphQL `createCommitOnBranch` and moves the local branch onto the signed
commit:

```sh
git add -A
agent-commit -m "feat: something" -m "Body."   # or -F <file>
```

- It pushes as it commits; there is no separate `git push`. A branch missing on origin is created
  at `HEAD`, which must already be on GitHub.
- It refuses if the local branch has commits that origin lacks, and for new executables or mode
  changes: the API has no file mode, so new files land as `100644`. Commit those with `git commit`.
- No merge commits; rebase onto the base branch instead.
- `AGENT_COMMIT_MODE=local` turns it into plain `git commit`, for repos that do not want API
  commits.

Live test: `client/agent-commit-live.sh org/repo` (needs a login and write access; cleans up its branch).

## On the host

Requirements: `bash`, `curl`, `jq`. With Claude Code, the plugin brings the scripts
([docs/claude-plugin.md](../docs/claude-plugin.md)). Otherwise install a release (`agent-run` finds
`agent-token` on your `PATH`):

```sh
brew tap pflege-de-labs/token-broker https://github.com/pflege-de-labs/token-broker
brew install agent-token
# or, into ~/.local/bin (PREFIX overrides; pin with `bash -s -- --version vX.Y.Z`):
curl -fsSL https://raw.githubusercontent.com/pflege-de-labs/token-broker/main/scripts/install.sh | bash
agent-token my-org/my-repo   # prints a 1h agent token
```

Both check the tarball's sha256, install `agent-gh` under that name (installed as `gh`, it would
also catch your own `gh` calls) and leave your git config alone: the credential helper setup below
is for containers only.

The login token is cached in `~/.cache/agent-token/login.json` (mode 600) for 8 hours. Without a
container, deny the agent read access to `~/.ssh`, `~/.config/gh` and `~/.cache/agent-token`.

## In an image, without the feature

- `bash`, `curl`, `jq`, `git`, `gh`; `github-mcp-server` only for the MCP server.
- The scripts in `/usr/local/bin`, with `agent-gh` installed **as `gh`**. It must come before the
  real `gh` in `PATH`; the wrapper finds the real one itself.
- `TOKEN_BROKER_URL` in the environment.
- System git config:

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

- A volume for `~/.cache/agent-token`, so the login survives container restarts. It holds the
  developer's login token (8h) and agent tokens (1h); keep it per developer, never shared.

The agent should act only as the agent app, so the wrapper refuses `gh auth login`, `refresh` and
`setup-git`; outside a checkout `gh auth status` reports the agent-token login instead. Commands without one target repo (`gh api orgs/...`) get no agent token and fail
unauthenticated, by design.

Install a pinned release, checked against its sha256 (from the release's `checksums.txt`):

```dockerfile
FROM docker.io/library/debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl git gh jq \
 && rm -rf /var/lib/apt/lists/*
ARG AGENT_TOKEN_VERSION=<release, e.g. 0.6.0>
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
ENV TOKEN_BROKER_URL=https://token-broker.internal
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

A complete devcontainer (egress firewall, Claude Code managed settings, VS Code credential
forwarding closed) is this repo's [`.devcontainer/`](../.devcontainer), described in
[docs/containers.md](../docs/containers.md).
