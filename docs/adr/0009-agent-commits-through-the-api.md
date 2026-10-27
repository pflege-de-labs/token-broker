# 9. Agent commits through the API

- Status: accepted
- Date: 2026-10-27

## Context

main requires verified signatures. GitHub signs app commits only when it creates them (API, web
UI); a `git commit` pushed with an agent token stays unsigned. The app has no key of its own to
sign with locally.

## Decision

In the devcontainer the agent commits with `agent-commit` (devcontainer-features), which sends the
staged changes to GraphQL `createCommitOnBranch` and moves the local branch onto the signed result.
Managed memory (`/etc/claude-code/CLAUDE.md`) tells Claude Code to use it. `AGENT_COMMIT_MODE=local`
switches back to `git commit` per repository.

## Alternatives

- **Plain `git commit`, squash merge only:** works, but branch commits stay unverified and every
  merge depends on picking squash.
- **A `git` wrapper that replays pushes through the API:** transparent, but has to parse every
  `git push` form and rewrite local history.

## Consequences

- Commit and push are one step; local commits ahead of origin are refused.
- The API has no file mode: new executables and mode changes need `git commit` and a squash merge.
- Commits are authored by the app with GitHub's timestamps; trailers in the message are kept.
