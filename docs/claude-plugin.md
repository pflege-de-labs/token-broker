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
`TOKEN_BROKER_URL` (see the [README](../README.md#use-it-locally)).

## What it does

A `SessionStart` hook ([`session-start.sh`](../plugins/agent-token/hooks/session-start.sh)) reads
the current repository's topics with `gh repo view`. github-ops sets the topic
`agent-token-broker` on every repository with `agent: true`, the same flag that installs the agent
app. With the topic, the hook adds [`agent-token.md`](../plugins/agent-token/hooks/agent-token.md)
and the result of `agent-token --check` to Claude's context; without `agent-token` on `PATH` it
tells Claude not to write to GitHub. Every other directory gets no output.

In such a session a `PreToolUse` hook ([`guard.sh`](../plugins/agent-token/hooks/guard.sh))
blocks Bash commands with `git commit` or `git push`, and with a bare `gh` where `agent-gh` exists
(in the devcontainer `gh` already is the wrapper). The session start leaves a marker in
`$TMPDIR/claude-agent-token/<session id>` for it. Cases: `plugins/agent-token/test.sh`, run in CI.

## Limits

- It is a guardrail, not a sandbox: the guard matches command text, so `env git push`,
  `/usr/bin/git push` or a script that pushes get through with the developer's credentials. For
  isolation run the agent with [`agent-run`](local.md) or the [devcontainer](containers.md).
- The marker belongs to the session, not the directory: after a `cd` into another repo the guard
  still applies, and a session started outside an agent-token repo stays unguarded.
- Repo admins can edit topics by hand. The broker still refuses tokens where the app is not
  installed, so a wrong topic costs a failed call, nothing more.
