
This repository has the token-broker agent app installed: write to GitHub as the agent app with
short-lived agent tokens, never with the user's own `gh` login, git credentials or SSH keys.

- Commit with `agent-commit`, not `git commit`: stage with `git add`, then
  `agent-commit -m "<subject>" [-m "<body>"]` or `agent-commit -F <file>`. GitHub creates and signs
  the commit and pushes it in the same step, so there is no separate `git push`.
  Rebase instead of merging, and pull before committing when origin moved.
  It refuses new executables and mode changes; for those, ask the user.
  Large changes (over 3 MB, e.g. generated files) go up as several `(part i/n)` commits by
  themselves; if it fails midway, rerun the same `agent-commit` to send the rest.
- GitHub CLI: `agent-gh` instead of `gh`. In the agent devcontainer `gh` already is that wrapper;
  from the host, run it there in one standalone command with the container part in single quotes:
  `podman exec -u vscode <container> bash -lc '<gh command>'`.
  If that fails, ask the user; never call `gh` by another path.
- Worktrees: create them inside the checkout with relative paths,
  `git worktree add --relative-paths .worktrees/<name> -b <branch>` (git 2.48+), and add
  `/.worktrees/` to `.git/info/exclude`. A devcontainer mounts only the checkout, so worktrees
  elsewhere or with absolute paths break there.
- When a call fails with `run: agent-token --login`, or the guard says the login is missing or
  stale, stop and ask the user to run `! agent-token --login`. Never fall back to their
  credentials: no `git commit`/`git push` over SSH, no `gh`, no GitHub MCP tools.
- Default tokens cannot change `.github/workflows/` or dispatch/re-run workflows. If the task needs
  that, ask the user to run `! agent-token --login`, then within 10 minutes prefix only those calls
  with `AGENT_TOKEN_SCOPE=workflows` (edit) or `AGENT_TOKEN_SCOPE=actions` (run).
