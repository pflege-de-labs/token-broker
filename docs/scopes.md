# Scopes: editing or running workflows

Agent tokens can commit, push, open PRs and work on issues. Two opt-in scopes add one permission
each, for one token at a time (ADR 16):

| Scope | Adds | For |
|---|---|---|
| `default` | nothing | everything else |
| `workflows` | `workflows: write` | pushing changes under `.github/workflows/` |
| `actions` | `actions: write` | `workflow_dispatch`, re-running jobs |

No token holds both: the broker refuses to start if a scope would.

## Enable

1. Grant the agent app the permission (*Workflows: Read and write*, *Actions: Read and write*)
   and accept it on every installation ([docs/github-apps.md](github-apps.md)). GitHub refuses
   tokens for installations that have not accepted.
2. Chart values:

   ```yaml
   config:
     scopes: [workflows]          # AGENT_SCOPES
     actionsOidc:
       # Workflows that may request a scope (ACTIONS_SCOPE_WORKFLOWS); empty: none.
       scopeWorkflows: ["acme/app/.github/workflows/release.yml@refs/heads/main"]
   ```

   If `agentPermissions` contains `actions: write`, remove it and enable the `actions` scope
   instead; otherwise the `workflows` scope would hold both and the broker does not start.

## Use

Developers: log in anew, then request the scope within 10 minutes. The broker checks that the
login is that recent, so an agent cannot elevate itself with a cached login.

```sh
agent-token --login                              # in Claude Code: ! agent-token --login
AGENT_TOKEN_SCOPE=workflows agent-commit -m "ci: …"
AGENT_TOKEN_SCOPE=actions gh run rerun 1234 --failed
```

The elevated token is cached per scope for its hour; calls without `AGENT_TOKEN_SCOPE` keep
using the default token. `AGENT_TOKEN_SCOPE=workflows agent-run` runs a whole session with the
scope; it ends after one hour, because renewing needs another fresh login.

Workflows: add `"scope":"workflows"` to the request body. Only workflows matching
`scopeWorkflows` get it.

## Before enabling `workflows` on a repository

A pushed workflow runs on its `push` or `pull_request` trigger; it does not need
`actions: write`. So an agent with `workflows` can run code it wrote, with whatever that branch
can reach. Make agent branches unprivileged first:

- Secrets only in **environments** whose deployment branch policy allows protected branches only,
  with required reviewers for production. No repository or organization secrets.
- `ACTIONS_ALLOWED_REFS` limited to protected branches, so a workflow on an agent branch cannot
  get an agent token itself.
- Cloud OIDC trust policies pinned to a `ref` or `environment`, not only the repository.
- Organization default `GITHUB_TOKEN` permissions read-only; *Allow GitHub Actions to create and
  approve pull requests* off.
- Self-hosted runner groups limited to selected workflows on protected branches.
- `.github/workflows/` owned by a human team in `CODEOWNERS` (code owner review is already
  required, [review rules](github-apps.md#agent-app)).

## Triggering without `actions`

`repository_dispatch` needs only `contents: write`, which every agent token has, and runs the
default-branch version of a workflow. Repositories that want agents to start reviewed workflows
can add `on: repository_dispatch` instead of enabling `actions`. Such a workflow must not check
out a ref from `client_payload` while secrets are available.

`actions: write` also lets the agent cancel and delete runs and logs, disable workflows and
delete caches.
