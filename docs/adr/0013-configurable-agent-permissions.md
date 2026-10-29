# 13. Configurable agent token permissions

- Status: accepted
- Date: 2026-10-29

## Context

ADR 1 fixes agent tokens to contents, pull requests and issues (write) and metadata (read), and the
broker hard-codes that set. Granting the app another permission, such as actions, does nothing for
agents until the broker is rebuilt.

## Decision

`AGENT_PERMISSIONS` (`name:level,...`, chart value `config.agentPermissions`) replaces the set the
broker requests per token. Unset, it keeps the ADR 1 set. The broker refuses to start on an entry
that is not `name:read` or `name:write`, and never sends an empty set, which GitHub would answer
with every permission of the app.

## Alternatives

- **Request everything the app has:** app settings would silently widen agent tokens.
- **Add permissions in code per need:** a release for each change; deployments cannot differ.

## Consequences

- A deployment can widen agent tokens without a code review in this repo; the cc-gitops PR is the
  review point.
- Every installation must accept a new app permission first, or GitHub refuses the token for its repos.
