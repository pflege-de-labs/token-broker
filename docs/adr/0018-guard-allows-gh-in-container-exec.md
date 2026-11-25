# 18. Plugin guard allows gh inside a container exec

- Status: accepted
- Date: 2026-11-25
- Amends: ADR 17

## Context

Claude on the host drives the agent devcontainer with `podman exec` or `devcontainer exec`. There
`gh` is the `agent-gh` wrapper and the container has its own login cache, but the plugin's bin/,
and so `agent-gh`, is not on the container's PATH. The guard matched `gh` anywhere in the command
text, so it blocked every PR or API call into the devcontainer, and it checked the host login,
not the container's.

## Decision

- The guard does not count `gh` as a host call when the whole command is one
  `podman exec`, `docker exec` or `devcontainer exec`, and everything outside single quotes is
  plain words on one line (letters, digits, spaces, tabs, `_ . / : = @ , + % -`). Single-quoted
  text reaches the container unexpanded.
- It still blocks when the command names `GH_TOKEN`, `GITHUB_TOKEN` or `--env-file`, which could
  hand the user's token to the container, and when it calls `gh` by a path, which skips the
  wrapper.
- Such a call skips the host login check; the wrapper in the container checks its own login.
- `git commit` and `git push` stay blocked inside an exec too.

## Alternatives

- **Ship `agent-gh` in the devcontainer feature:** needs a release in another repository and
  still leaves the host login check pointing at the wrong cache.
- **Probe the target container for the wrapper:** parsing the container name out of `exec` options
  is fragile, and the guard only matches command text anyway (see the limits in
  [claude-plugin.md](../claude-plugin.md#limits)).

## Consequences

- The guard trusts that the container is the agent devcontainer. A different container whose `gh`
  has the user's credentials (mounted `~/.config/gh`, `GH_TOKEN` from `remoteEnv`) gets through.
- Shell-wrapped execs such as `fish -l -c 'devcontainer exec …'` stay blocked.
