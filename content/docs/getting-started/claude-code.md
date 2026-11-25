---
title: Claude Code plugin
weight: 1
---

Install the `agent-token` plugin so Claude Code on your host commits and calls GitHub as the agent
app instead of as you.

## Before you start

* `jq`, `gh` (logged in), `curl` and `git` on the host.
* The agent app is installed on your repository, and the repository carries the topic
  `agent-token-broker`.
* The broker's URL. The plugin looks for it in this order: the `TOKEN_BROKER_URL` environment
  variable, the plugin option `broker_url`, the Actions variable `AGENT_TOKEN_BROKER_URL` of the
  repository's organization, read with your `gh`. Repository variables are ignored, so a repository
  admin cannot send your login to another server. Only `https://` URLs are accepted.

## Install

```sh
claude plugin marketplace add pflege-de-labs/token-broker
claude plugin install agent-token@pflege-de-token-broker
```

To set the broker URL at install time, add `--config broker_url=https://<broker>`. You can also
set it later in Claude Code with `/config`.

The plugin carries the client scripts: its `bin/` directory is on the PATH of Claude's Bash tool.
Your own `PATH` comes first, so a Homebrew or script install wins. The plugin tracks `main`, while
Homebrew, the install script and the containers install pinned releases. Marketplace auto-update
is off by default; update with `claude plugin update agent-token@pflege-de-token-broker`.

## Log in

Once per 8 hours, in the Claude Code prompt:

```text
! agent-token --login
```

The first login prints a code for <https://github.com/login/device>. The login token is cached in
`~/.cache/agent-token/login.json`.

## What happens in a session

A `SessionStart` hook checks whether the repository carries the topic `agent-token-broker`. If it
does, Claude is told to commit and call GitHub with agent tokens, and the hook adds the result of
`agent-token --check`. In every other directory the plugin stays silent.

In such a session a `PreToolUse` hook blocks Bash commands that contain `git commit` or
`git push`, and `gh`, also called by its full path. Claude uses
[`agent-commit`](../../guides/signed-commits/) and `agent-gh` instead.

`gh` inside one standalone `podman exec`, `docker exec` or `devcontainer exec` is allowed, since in
the [Dev Container](../devcontainer/) `gh` is the wrapper with the container's own login. The
container's command goes in single quotes, for example
`podman exec -u vscode <container> bash -lc 'gh pr create --fill'`. Commands chained around the
exec, `GH_TOKEN`, `GITHUB_TOKEN`, `--env-file` and `gh` by a path stay blocked.

Before a commit, a push or `agent-gh pr create`, the hook also checks your login. If it is missing
or expires within 5 minutes, the command is blocked and Claude asks you to run
`! agent-token --login`, instead of committing or pushing another way.

If your `gh` is the `agent-gh` wrapper and your login has expired, the plugin cannot read the
topic either. Claude is then told to ask you for a login, and the hook blocks `git commit`,
`git push` and `gh` until you have logged in.

The check also runs later: before a `git commit`, `git push` or `gh` command in an unguarded
session, the guard checks the repository the command targets. A session started before the app was
installed, or in a parent directory, is guarded from that command on.

{{< callout type="warning" >}}
The plugin is a guardrail, not a sandbox. The hook matches command text, so `g=git; $g push` or a
script that pushes get through with your credentials. Nor does it check which container an exec
targets: one whose `gh` has your login gets through. GitHub MCP tools are not checked. For
isolation use the [container](../container/) or the [Dev Container](../devcontainer/). See the
[security model](../../concepts/security-model/).
{{< /callout >}}

## Next steps

* [Sign agent commits](../../guides/signed-commits/)
* [Client commands](../../reference/client-cli/)
