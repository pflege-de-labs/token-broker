
This repository has the token-broker agent app installed: write to GitHub as the agent app with
short-lived agent tokens, never with the user's own `gh` login, git credentials or SSH keys.

- Commit with `agent-commit`, not `git commit`: stage with `git add`, then
  `agent-commit -m "<subject>" [-m "<body>"]` or `agent-commit -F <file>`. GitHub creates and signs
  the commit and pushes it in the same step, so there is no separate `git push`.
  Rebase instead of merging, and pull before committing when origin moved.
  It refuses new executables and mode changes; for those, ask the user.
- GitHub CLI: `agent-gh` instead of `gh` (in the agent devcontainer, `gh` already is that wrapper).
- Worktrees: create them inside the checkout with relative paths,
  `git worktree add --relative-paths .worktrees/<name> -b <branch>` (git 2.48+), and add
  `/.worktrees/` to `.git/info/exclude`. A devcontainer mounts only the checkout, so worktrees
  elsewhere or with absolute paths break there.
- When a call fails with `run: agent-token --login`, ask the user to run `! agent-token --login`;
  do not fall back to their credentials.
- Default tokens cannot change `.github/workflows/` or dispatch/re-run workflows. If the task needs
  that, ask the user to run `! agent-token --login`, then within 10 minutes prefix only those calls
  with `AGENT_TOKEN_SCOPE=workflows` (edit) or `AGENT_TOKEN_SCOPE=actions` (run).
