---
title: Dev Container
weight: 5
---

The `agent-token` Dev Container Feature installs the client scripts, pinned to a release, into a
devcontainer. It is published in
[pflege-de-labs/devcontainer-features](https://github.com/pflege-de-labs/devcontainer-features#agent-token).

The token-broker repository's own
[`.devcontainer/`](https://github.com/pflege-de-labs/token-broker/tree/main/.devcontainer) is a
working setup to copy. It:

* installs the scripts with the Feature (pinned by digest in `devcontainer.json`);
* sets the bot identity and installs Claude Code and the toolchain from `mise.toml`;
* adds a SessionStart hook as managed settings, which reminds you when the login is missing;
* limits outbound traffic with an egress firewall to an allowlist of domains plus the broker host.

On first attach the terminal shows a device code; log in there. With Podman, set
`"dev.containers.dockerPath": "podman"` in your VS Code settings.

## Choose the client release

The Feature installs the client release it pins and checks the download against a sha256 reviewed
in devcontainer-features. To install another release, set the Feature's `version` option:

```jsonc
"features": {
  "ghcr.io/pflege-de-labs/devcontainer-features/agent-token:1": { "version": "0.7.0" }
}
```

| Option | Default | Description |
| --- | --- | --- |
| `version` | empty: the pinned release | A token-broker release, e.g. `0.7.0`. Checked only against that release's `checksums.txt`. |

A new client release becomes the default with a new Feature version. Rebuild the devcontainer to
pick it up.

## Broker URL and login app

Two Actions variables supply the broker URL and the login app client ID, not the repository:

| Variable | Container environment |
| --- | --- |
| `AGENT_TOKEN_BROKER_URL` | `TOKEN_BROKER_URL` |
| `AGENT_LOGIN_CLIENT_ID` | `LOGIN_APP_CLIENT_ID` |

A repository variable of the same name overrides the organization value. Nothing in the container
can read variables, so
[`broker-env.sh`](https://github.com/pflege-de-labs/token-broker/blob/main/.devcontainer/broker-env.sh)
runs on the host as `initializeCommand`. It needs `gh` (logged in, `repo` scope) and `jq`, reads
both variables for the `origin` repository and writes `.devcontainer/.env`, which `runArgs` passes
with `--env-file`:

```jsonc
{
  "initializeCommand": ".devcontainer/broker-env.sh",
  "runArgs": ["--env-file=${localWorkspaceFolder}/.devcontainer/.env"]
}
```

## Things to know

* Everything committed or pushed in the container goes out as the agent app's bot, including
  commits from the VS Code Source Control view. Commit as yourself from the host.
* The agent commits with [`agent-commit`](../../guides/signed-commits/), so branches that require
  signatures accept them.
* VS Code forwards your credentials into devcontainers. The setup turns off
  `git.terminalAuthentication` and `github.gitAuthentication`, overrides `GIT_AUTHOR_*` and
  `GIT_COMMITTER_*`, and has the credential helper answer `quit=1` when it has no token. Your SSH
  agent is still forwarded: the firewall blocks port 22, but it can still sign. For full
  isolation use [`agent-run`](../container/).
* A git worktree does not work as the workspace, because its `.git` points outside the mount.
  Open a clone.
* Network access beyond the allowlist needs a change to `allowed-domains` and a rebuild.

For an image without the Feature, see
[Use the scripts in your own image](../../guides/image-without-feature/). To use the GitHub MCP
server, see [`agent-github-mcp`](../../reference/client-cli/#agent-github-mcp).
