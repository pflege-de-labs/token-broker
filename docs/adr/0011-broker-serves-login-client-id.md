# 11. Broker serves the login client ID

- Status: accepted
- Date: 2026-10-28

## Context

ADR 8 makes every client set both the broker URL and the login app client ID. It rejected reading
config inside the container because the client ID is needed before the login. The broker already
knows that ID (`LOGIN_APP_CLIENT_ID`), and the client reaches the broker before the login anyway.

## Decision

The broker serves `GET /login-app` without authentication: `{"client_id": "<login app client ID>"}`.
`agent-token` fetches it when `LOGIN_APP_CLIENT_ID` is unset. Clients only set `TOKEN_BROKER_URL`;
`LOGIN_APP_CLIENT_ID` stays as an override. This replaces the client ID half of ADR 8.

## Alternatives

- **Keep both variables (ADR 8):** every client and every org repeats a value the broker already has.
- **Default in the feature:** ties the public feature to one deployment.

## Consequences

- The client ID is public anyway (device flow has no secret on the client); the endpoint reveals
  nothing a login prompt would not. Like `/token`, it stays on the internal route (ADR 3).
- The `AGENT_LOGIN_CLIENT_ID` org variable becomes optional once all devcontainers use an
  `agent-token` feature that fetches the ID.
