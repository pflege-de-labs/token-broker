# Claude Code plugin `agent-token`

Without a container, Claude Code runs with the developer's own `gh` login and SSH keys. The plugin
tells it, at session start, to commit and call GitHub as the agent app instead, in every
repository the agent app is installed on.

## Install

```sh
claude plugin marketplace add pflege-de-labs/token-broker
claude plugin install agent-token@pflege-de-token-broker   # optional: --config broker_url=https://<broker>
```

Then, once per 8h, log in from the Claude prompt: `! agent-token --login`. Needs `gh` (logged in),
`jq`, `curl` and `git` on the host. The plugin follows `main`; marketplace auto-update is off by
default, so update with `claude plugin update agent-token@pflege-de-token-broker` or turn it on in `/plugin`.

## What it does

The plugin's `bin/` holds the [client scripts](../client/README.md). Claude Code puts it on the
Bash tool's `PATH`, after your own entries, so an `agent-token` from Homebrew or
`scripts/install.sh` takes precedence.

A `SessionStart` hook ([`session-start.sh`](../plugins/agent-token/hooks/session-start.sh)) reads
the current repository's topics with `gh repo view`. github-ops sets the topic
`agent-token-broker` on every repository with `agent: true`, the same flag that installs the agent
app. Every other directory gets no output. With the topic, the hook:

- checks for `jq`, `curl` and `git`; if one is missing, it tells Claude not to write to GitHub;
- finds the broker URL: `TOKEN_BROKER_URL`, else the plugin option `broker_url` (`/config`), else
  the org Actions variable `AGENT_TOKEN_BROKER_URL`. It never reads repo variables, so a repo
  admin cannot redirect logins. It accepts `https://` URLs only and exports the URL to later Bash
  commands through `CLAUDE_ENV_FILE`;
- adds [`agent-token.md`](../plugins/agent-token/hooks/agent-token.md) and the result of
  `agent-token --check` to Claude's context.

In such a session a `PreToolUse` hook ([`guard.sh`](../plugins/agent-token/hooks/guard.sh))
blocks Bash commands with `git commit`, `git push` or a bare `gh`. Without `jq` it blocks every
command, since it cannot read them. The session start leaves a marker in
`$TMPDIR/claude-agent-token/<session id>` for it. Cases: `plugins/agent-token/test.sh`, run in CI.

## Limits

- It is a guardrail, not a sandbox: the guard matches command text, so `env git push`,
  `/usr/bin/git push` or a script that pushes get through with the developer's credentials. For
  isolation run the agent with [`agent-run`](local.md) or the [devcontainer](containers.md).
- The marker belongs to the session, not the directory: after a `cd` into another repo the guard
  still applies, and a session started outside an agent-token repo stays unguarded.
- Repo admins can edit topics by hand. The broker still refuses tokens where the app is not
  installed, so a wrong topic costs a failed call, nothing more.
