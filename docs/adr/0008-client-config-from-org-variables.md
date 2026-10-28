# 8. Client config from org variables

- Status: accepted; client ID part superseded by ADR 11
- Date: 2026-10-26

## Context

Every devcontainer needs the broker URL (internal route) and the login app client ID. Hard-coding
them per repository repeats them everywhere, and the public devcontainer-features repository
should not carry the internal hostname (ADR 7).

## Decision

github-ops sets the Actions variables `AGENT_TOKEN_BROKER_URL` and `AGENT_LOGIN_CLIENT_ID` in
every org, visible to all repositories; a repository variable overrides them. The devcontainer
reads them on the host with the developer's `gh` (`initializeCommand`) and passes them into the
container as `TOKEN_BROKER_URL` and `LOGIN_APP_CLIENT_ID`. `TOKEN_BROKER_URL` keeps its meaning
for workflows (ADR 3).

## Alternatives

- **Broker writes the variables when the agent app is added to a repository:** the agent app
  would need Variables write, so its private key could redirect `TOKEN_BROKER_URL` in every
  installed repository. The broker would also need webhooks or polling (ADR 2).
- **Read them inside the container:** the login app has no permissions and agent tokens lack
  Variables read; the client ID is needed before the login anyway.
- **Defaults in the feature:** puts the internal hostname into a public repository.

## Consequences

- Developers need `gh` and `jq` on the host for the devcontainer.
- Variables are readable only by repository collaborators; the broker requires write access
  anyway.
