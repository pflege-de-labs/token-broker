# 15. Host install: plugin, Homebrew and install script

- Status: accepted
- Date: 2026-10-29

## Context

Using an agent token from Claude Code on the host took three manual steps: the client scripts on
`PATH`, `TOKEN_BROKER_URL` in the environment Claude Code inherits (which is not always the login
shell's), and the plugin. Without Claude Code (`agent-run`, plain shells) the scripts came from a
checkout or a hand-downloaded tarball.

## Decision

- The client scripts move from `client/bin` into the plugin as `plugins/agent-token/bin`, which
  Claude Code puts on the Bash tool's `PATH`. Installing the plugin installs the scripts. A
  symlink would not work: Claude Code ignores symlinks that leave the plugin directory.
- The plugin's SessionStart hook finds the broker URL in this order: `TOKEN_BROKER_URL`, then
  the plugin option `broker_url`, then the org Actions variable `AGENT_TOKEN_BROKER_URL`, read
  with the user's `gh`. It hands the URL to later Bash commands through `CLAUDE_ENV_FILE`.
  Repo variables are not read, so a repo admin cannot send developer logins to another server.
- Release tarballs (ADR 14) are still built, now from the plugin's `bin/`, with the version
  stamped into `agent-token --version`. Two more installers use them, both checked against sha256:
  - `scripts/install.sh` (`curl | bash`) installs into `~/.local/bin`.
  - A Homebrew formula in `Formula/` of this repo. A release job opens the formula bump PR as the
    agent app.
- Neither installer installs `agent-gh` as `gh` or changes the global git config.

## Alternatives

- **Separate `homebrew-tap` repo:** gives a shorter `brew tap`, but the release workflow's agent
  token covers only this repo, so the tap would need its own bump workflow.
- **Plugin pinned to releases (`version` in `plugin.json`):** every release would need a manifest
  bump. Instead, host plugins track `main`, and brew, the script and containers stay on pinned releases.
- **Config file for the broker URL:** `CLAUDE_ENV_FILE` already reaches the Bash tool, and a file
  would be one more thing to keep in sync.

## Consequences

- The plugin needs `gh`, `jq`, `curl` and `git` on the host. Without `gh` the plugin stays silent.
  Without one of the others it tells Claude not to write to GitHub, and the guard blocks every
  command in the marked session when `jq` is missing.
- Host plugin users get script changes on `main` before a release (marketplace auto-update is
  off by default, so they run `claude plugin update`).
- The formula job needs the org variable `TOKEN_BROKER_URL` (public Actions route), like other
  agent workflows. The formula PR needs a human review.
