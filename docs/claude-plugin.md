# Claude Code plugin `agent-token`

Without a container, Claude Code runs with the developer's own `gh` login and SSH keys. The plugin
tells it, at session start, to commit and call GitHub as the agent app instead, in every
repository the agent app is installed on.

## Install

```sh
claude plugin marketplace add pflege-de/token-broker
claude plugin install agent-token@pflege-de-token-broker
```

Needs `gh` (logged in) and, for the actual work, the client scripts on `PATH` plus
`TOKEN_BROKER_URL` and `LOGIN_APP_CLIENT_ID` (see the [README](../README.md#use-it-locally)).

## What it does

A `SessionStart` hook ([`session-start.sh`](../plugins/agent-token/hooks/session-start.sh)) reads
the current repository's topics with `gh repo view`. github-ops sets the topic
`agent-token-broker` on every repository with `agent: true`, the same flag that installs the agent
app. With the topic, the hook adds [`agent-token.md`](../plugins/agent-token/hooks/agent-token.md)
and the result of `agent-token --check` to Claude's context; without `agent-token` on `PATH` it
tells Claude not to write to GitHub. Every other directory gets no output.

## Limits

- It is an instruction, not a sandbox: Claude still could use the developer's credentials. For
  isolation run the agent with [`agent-run`](local.md) or the [devcontainer](containers.md).
- Repo admins can edit topics by hand. The broker still refuses tokens where the app is not
  installed, so a wrong topic costs a failed call, nothing more.
