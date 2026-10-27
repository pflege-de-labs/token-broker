# Commits in this container

Commit with `agent-commit`, not `git commit`: stage with `git add`, then
`agent-commit -m "<subject>" [-m "<body>"]` or `agent-commit -F <file>`. GitHub creates and signs
the commit and pushes it in the same step, so there is no separate `git push`.
Rebase instead of merging, and pull before committing when origin moved.
It refuses new executables and mode changes; for those, ask the user.
