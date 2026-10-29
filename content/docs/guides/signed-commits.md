---
title: Sign agent commits
weight: 3
---

`git commit` in a container makes unsigned commits: GitHub signs app commits only when it creates
them itself. Rulesets with `required_signatures` then block them on protected branches. Squash
merges still work, because GitHub signs the squash commit.

`agent-commit` sends the staged changes to the GraphQL mutation `createCommitOnBranch` and moves
the local branch onto the signed commit:

```sh
git add -A
agent-commit -m "feat: something" -m "Body."   # or -F <file>
```

* It pushes as it commits; there is no separate `git push`. A branch missing on origin is created
  at `HEAD`, which must already be on GitHub.
* It refuses if the local branch has commits that origin lacks, and for new executables or mode
  changes: the API has no file mode, so new files land as `100644`. Commit those with
  `git commit` and merge with squash.
* It creates no merge commits; rebase onto the base branch instead.
* `AGENT_COMMIT_MODE=local` turns it into plain `git commit`, for repositories that do not want
  API commits.

In the Dev Container, `/etc/claude-code/CLAUDE.md` tells Claude Code to use `agent-commit`. With
the Claude Code plugin, the guard blocks `git commit` and points Claude here.

See [`agent-commit`](../../reference/client-cli/#agent-commit) for the full reference.
