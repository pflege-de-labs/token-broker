---
title: Client environment
weight: 2
---

Variables the client scripts and `agent-run` read.

| Variable | Used by | Meaning |
| --- | --- | --- |
| `TOKEN_BROKER_URL` | `agent-token` and the scripts built on it | Broker URL. Required. |
| `LOGIN_APP_CLIENT_ID` | `agent-token` | Overrides the login app client ID that the broker serves at `/login-app`. |
| `AGENT_TOKEN_NONINTERACTIVE` | `agent-token` | `1` fails instead of starting a device flow. Set by the other scripts. |
| `XDG_CACHE_HOME` | `agent-token`, `agent-run` | Base of the cache directory; default `~/.cache`. The cache is `<base>/agent-token`. |
| `AGENT_COMMIT_MODE` | `agent-commit` | `local` runs plain `git commit`; default `api`. |
| `GH_REPO` | `agent-gh` | Target repository, as for `gh`. |
| `AGENT_APP_SLUG` | `agent-run` | Slug of the agent app. Required. |
| `AGENT_IMAGE` | `agent-run` | Image to run; default `localhost/agent-sandbox:latest`. |
| `AGENT_PODMAN_ARGS` | `agent-run` | Extra `podman run` flags. |
| `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY` | `agent-run` | Passed into the container for Claude Code's authentication. |

## Where the broker URL comes from

* Claude Code plugin: `TOKEN_BROKER_URL`, else the plugin option `broker_url`, else the Actions
  variable `AGENT_TOKEN_BROKER_URL` of the organization (never the repository), read with your `gh`.
* Dev Container: `AGENT_TOKEN_BROKER_URL` and `AGENT_LOGIN_CLIENT_ID` are read on the host and
  passed in as `TOKEN_BROKER_URL` and `LOGIN_APP_CLIENT_ID`; see
  [Dev Container](../../getting-started/devcontainer/).
* Everything else: set `TOKEN_BROKER_URL` yourself.
