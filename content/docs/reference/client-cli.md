---
title: Client commands
weight: 1
---

The client scripts live in `bin/` of every `agent-token-<version>.tar.gz` release asset and of the
Claude Code plugin. They need `bash`, `curl` and `jq`. All of them read the
[client environment](../client-env/).

| Script | Role |
| --- | --- |
| `agent-token` | Device-flow login, login check, token per repository with a cache |
| `agent-token-git-credential` | git credential helper for `github.com` |
| `agent-gh` | Wrapper for `gh` that sets `GH_TOKEN` for the target repository |
| `agent-github-mcp` | Starts the local `github-mcp-server` with a token for the current repository |
| `agent-commit` | Commits the staged changes through the GitHub API, so GitHub signs them |

## `agent-token`

```text
agent-token org/repo                  prints a 1h agent token for that repository
agent-token --login                   logs in via the login app's device flow (interactive)
agent-token --check                   exits 1 unless a login is cached
agent-token --permissions org/repo    prints the permissions GitHub granted that token (JSON)
agent-token --version                 prints the version (from v0.7.0)
```

The login token is cached in `~/.cache/agent-token/login.json` (mode 600) for 8 hours. A token
per repository is reused until 5 minutes before it expires. Needs `TOKEN_BROKER_URL`. The login
app's client ID comes from the broker (`GET /login-app`); `LOGIN_APP_CLIENT_ID` overrides it.

Calls other than `--login` set `AGENT_TOKEN_NONINTERACTIVE=1` and fail with
`run: agent-token --login` instead of waiting for a device code nobody sees.

## `agent-token-git-credential`

A git credential helper that answers `github.com` requests with an agent token for the requested
repository and stays silent for other hosts. It answers `quit=1` when it has no token, so no later
helper answers instead. It needs `credential.useHttpPath=true`, otherwise git sends no path. The
system git config is in [Use the scripts in your own image](../../guides/image-without-feature/).

## `agent-gh`

Runs the real `gh` with `GH_TOKEN` set to an agent token for the target repository. The target is
the `--repo`/`-R` flag, else `GH_REPO`, else the `origin` remote. Install it as `gh` in containers,
ahead of the real `gh` in `PATH`; on the host the install script installs it as `agent-gh`.

* `gh auth login`, `refresh` and `setup-git` are refused.
* Outside a checkout, `gh auth status` reports the agent-token login.
* Commands without one target repository (`gh api orgs/...`) get no agent token and run with
  `gh`'s own authentication, if any.

## `agent-github-mcp`

Starts `github-mcp-server stdio` with an agent token for the `origin` repository of the current
directory; further arguments go to the server. Register it with Claude Code:

```sh
claude mcp add --scope user github -- agent-github-mcp --toolsets repos,issues,pull_requests
```

* The token is fixed for the server process: after 1 hour calls fail with 401. Reconnect via
  `/mcp`.
* One repository per server. Work on another repository needs a session started there.
* Installation tokens cannot call user endpoints, so tools like `get_me` fail.

The hosted GitHub MCP server and the claude.ai GitHub connector use your own identity, not the
agent's.

## `agent-commit`

```text
agent-commit -m <message> [-m <paragraph>]...
agent-commit -F <file>
```

Commits the staged changes through GraphQL `createCommitOnBranch`, so GitHub signs the commit,
pushes it and moves the local branch onto it. Details and limits:
[Sign agent commits](../../guides/signed-commits/). `AGENT_COMMIT_MODE=local` runs plain
`git commit` with the arguments instead.
