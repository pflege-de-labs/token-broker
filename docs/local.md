# Running an agent locally in a container

`agent-run` starts Claude Code in a container whose only GitHub credential is an agent token
for one repository. Your SSH keys, `gh` login, git config and the broker login token stay on the
host.

## Setup

Requirements: `podman`, `curl`, `jq`, `git`. Build the image once:

```sh
podman build -t localhost/agent-sandbox:latest container/
```

Set the broker URL and app names from the deployment (pflege-de:
[cc-gitops `docs/token-broker.md`](https://github.com/pflege-de/cc-gitops/blob/main/docs/token-broker.md)),
and how Claude Code authenticates:

```sh
export TOKEN_BROKER_URL=https://<broker>        # internal route
export LOGIN_APP_CLIENT_ID=<login app client ID>
export AGENT_APP_SLUG=<agent app slug>
export CLAUDE_CODE_OAUTH_TOKEN=<from `claude setup-token`>   # or ANTHROPIC_API_KEY
```

## Use

From inside a checkout (a clone or a git worktree):

```sh
/path/to/token-broker/agent-run                 # repo from the `origin` remote
/path/to/token-broker/agent-run my-org/my-repo  # explicit repo
/path/to/token-broker/agent-run -p "fix the failing test"   # arguments go to claude
```

What it does:

- gets an agent token via `agent-token` (device flow on first use) and renews it every 45
  minutes while the session runs; the container reads it from a read-only file;
- mounts the checkout at the same path, plus the main repository's `.git` for worktrees;
- rewrites GitHub SSH remotes to HTTPS, so git pushes with the agent token;
- sets the commit identity to `<app>[bot] <<bot user ID>+<app>[bot]@users.noreply.github.com>`;
- keeps Claude Code's settings in the named volume `agent-claude`;
- maps your user to the container user, so files keep your ownership.

`AGENT_IMAGE` selects another image, `AGENT_PODMAN_ARGS` adds podman flags (e.g.
`--entrypoint sh` for a shell instead of Claude).

## Limits

- The token covers one repository: fetching private dependencies from other repositories
  (e.g. Go modules) fails.
- Commits are unsigned; merge agent PRs with squash.
- After 8 hours the login token expires and the next renewal prints a device code on the
  terminal.
