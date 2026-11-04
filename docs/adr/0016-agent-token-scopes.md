# 16. Opt-in agent token scopes

- Status: accepted
- Date: 2026-11-04
- Amends: ADR 13

## Context

Agent tokens should only commit, push and open PRs by default. Some tasks need more: editing CI
workflows (`workflows:write`) or triggering and re-running them (`actions:write`). A token that
can do both lets an agent write a workflow and run it. ADR 13 has only one permission set for
every token, so widening it widens every agent session.

Separating tokens alone does not separate editing from running: a pushed workflow runs on its
`push`/`pull_request` trigger without `actions:write`, an edit on a branch outlives the token that
made it, and `repository_dispatch` needs only `contents:write`. What protects a repository is
that code from agent branches runs without privileges until a human merges it.

## Decision

- **Scopes.** `POST /token` takes `scope`. `default` is the `AGENT_PERMISSIONS` set. A deployment
  enables more with `AGENT_SCOPES`: `workflows` (default + `workflows:write`) and `actions`
  (default + `actions:write`). Clients name a scope, never permissions. Unknown or disabled
  scopes get 400. Scope is logged and a metrics label.
- **Never both.** The broker refuses to start if any issuable scope holds `workflows` and
  `actions:write`. A deployment with `actions:write` in `AGENT_PERMISSIONS` must move it to the
  `actions` scope before enabling `workflows`.
- **Step-up for developers.** An elevated scope needs a login token issued in the last 10
  minutes, so a human has just completed a device flow. The broker derives the issue time from
  the token's `expires_at` (GitHub user tokens live 8h); tokens without expiry are refused.
- **Actions.** Elevated scopes only for workflows matching `ACTIONS_SCOPE_WORKFLOWS`
  (`job_workflow_ref` globs); empty allows none.
- **Client.** `AGENT_TOKEN_SCOPE` selects the scope in `agent-token`, so `agent-commit`, `agent-gh`,
  the git credential helper and `agent-run` need no change. Tokens are cached per scope.
  `agent-token --login` always starts a new device flow.
- **Repository prerequisites** for `workflows` are documented in [docs/scopes.md](../scopes.md),
  not enforced by the broker.

## Alternatives

- **Client-supplied permission lists:** clients could compose any set the app has.
- **Exclusive tokens with broker state and revocation:** stateful, and still defeated by pushes
  and edits that stay on a branch.
- **Check-token `created_at` for the step-up:** unclear whether it is per token or per
  authorization; `expires_at` minus the documented 8h is what GitHub states.

## Consequences

- The app must be granted, and every installation must accept, each permission a scope adds.
  From then on the scope check is all that keeps them out of default tokens.
- An elevated token lives 1h; `agent-run` cannot renew it without a new login.
- If GitHub changes the user-token lifetime, the step-up window shifts: shorter refuses every
  elevated request, longer accepts older logins.
- In the devcontainer the agent shares the login cache, but cannot finish a device flow without
  the human entering the code.
