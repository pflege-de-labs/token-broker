# 17. Plugin guard blocks writes without a fresh agent login

- Status: accepted
- Date: 2026-11-16
- Amends: ADR 10

## Context

When the agent login was missing or expired, `agent-commit` failed and Claude looked for another
way: `git commit` and `git push` over the developer's SSH key, or `gh` by its full path. The
guard also stayed off when `gh` is the `agent-gh` wrapper: `gh repo view` itself needs the
expired login, so the failed topic check looked like "no agent repo".

## Decision

- In a guarded session the guard runs `agent-token --check` before `agent-commit`,
  `agent-gh pr create`, `git commit`, `git push` and `gh`. If the login is missing or expires
  within 5 minutes, it blocks and tells Claude to ask the user for `! agent-token --login`.
- `gh` is matched by any path (`/opt/homebrew/bin/gh`, `\gh`), and `git` with any options before
  `commit` or `push`.
- If `gh repo view` fails with the wrapper's `run: agent-token --login`, the topic is unknown: the
  session start tells Claude to ask for a login, and the guard blocks `git commit`, `git push` and
  `gh` until the topic check works again (fail closed).

## Alternatives

- **Check only in `agent-commit`:** it already fails; the failure is what made Claude look
  elsewhere.
- **Fail closed on every `gh` failure in a GitHub repo:** would block commits in every GitHub
  repo whenever `gh` is logged out or offline, agent-token repo or not.

## Consequences

- `agent-commit` is refused once the login is stale, even while a cached repo token would still
  work; the user logs in once more per 8 hours.
- Read-only `agent-gh` calls still run with a stale login.
- With a real `gh` that fails for other reasons, sessions stay unguarded as before.
- The GitHub MCP tools are not Bash commands and stay unguarded.
