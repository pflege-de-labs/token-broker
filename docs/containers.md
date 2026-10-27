# Agent tokens in containers

A coding agent in a container gets agent tokens on demand, per repo, from the client scripts in
[pflege-de-labs/devcontainer-features](https://github.com/pflege-de-labs/devcontainer-features)
(`src/agent-token/`). Its README lists what an image needs: the scripts, the system git config
and a volume for the login cache. This page covers the devcontainer of this repository.

## Devcontainer

[`.devcontainer/`](../.devcontainer) is a working setup for this repository; copy it for others.
It fetches the scripts at a pinned devcontainer-features commit (`AGENT_TOKEN_REF` in the
Dockerfile), sets the bot identity, installs Claude Code and the toolchain from `mise.toml`, and
adds the SessionStart hook below as managed settings. On first attach the terminal shows a device
code; log in there.

With Podman, set `"dev.containers.dockerPath": "podman"` in your VS Code settings.

### Broker URL and login app

The broker URL (internal route) and the login app client ID come from two GitHub Actions
variables, not from the repository (ADR 8):

| Variable | Container env | pflege-de value |
|---|---|---|
| `AGENT_TOKEN_BROKER_URL` | `TOKEN_BROKER_URL` | `https://token-broker.internal` |
| `AGENT_LOGIN_CLIENT_ID` | `LOGIN_APP_CLIENT_ID` | `<login app client ID>` |

github-ops sets them as org variables in every org (`variables` in `orgs/<org>/org.yaml`). A
repository variable of the same name overrides the org value, e.g. for a test broker, in
`orgs/<org>/repositories.yaml`:

```yaml
my-repo:
  variables:
    AGENT_TOKEN_BROKER_URL: https://token-broker.staging.example
```

They are not `TOKEN_BROKER_URL`: that org variable is the public `/token/actions` endpoint for
workflows ([actions.md](actions.md)).

Nothing in the container may read variables, so
[`broker-env.sh`](../.devcontainer/broker-env.sh) runs on the host as `initializeCommand`. It needs
`gh` (logged in, `repo` scope) and `jq`, reads both variables for the `origin` repo and writes
`.devcontainer/.env` (gitignored), which `runArgs` passes with `--env-file`. To use it in
another repository, copy the script and these keys:

```jsonc
{
  "initializeCommand": ".devcontainer/broker-env.sh",
  "runArgs": ["--env-file=${localWorkspaceFolder}/.devcontainer/.env"]
}
```

Check what the container will get:

```sh
.devcontainer/broker-env.sh && cat .devcontainer/.env
```

Everything committed or pushed in the container goes out as `pflege-de-agent[bot]`, your own
commits from the Source Control view included. Commit as yourself from the host.

`git commit` here makes unsigned commits, which main's `required_signatures` rule rejects
unless the PR is squash-merged. The agent therefore commits with `agent-commit` (from
devcontainer-features), which creates the commit through the GitHub API, signed by GitHub, and
pushes it in the same step. `/etc/claude-code/CLAUDE.md` tells Claude Code to use it. It cannot
commit new executables or mode changes; those need `git commit` and a squash merge.

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
the broker host. It reads `TOKEN_BROKER_URL` from PID 1's environment, which the agent cannot change. A local dnsmasq answers only those names and adds each resolved IP to the allowlist,
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
