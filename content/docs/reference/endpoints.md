---
title: Endpoints
weight: 4
---

| Method and path | Purpose | Audience |
| --- | --- | --- |
| `POST /token` | Agent token for a developer login token or an Actions OIDC token | internal |
| `POST /token/actions` | Agent token for an Actions OIDC token only | may be public |
| `GET /login-app` | Client ID of the login app | internal |
| `GET /healthz` | Liveness | probes |
| `GET /readyz` | Readiness | probes |
| `GET /metrics` | Prometheus metrics | scrapers |

## `POST /token`

Request:

```http
POST /token
Authorization: Bearer <login token or Actions OIDC token>
Content-Type: application/json

{"repo": "my-org/my-repo"}
```

The bearer token decides the path: a token with two dots is a GitHub Actions OIDC token, anything
else is a user token of the login app. The body is limited to 4096 bytes.

Response (200):

```json
{"token": "ghs_...", "expires_at": "2026-01-01T12:00:00Z", "permissions": {"contents": "write"}}
```

The token covers the one repository and lives one hour. Errors are plain-text bodies:

| Status | Cause |
| --- | --- |
| 400 | Invalid JSON, or `repo` is not `owner/name` |
| 401 | Missing bearer token, invalid or unreadable Actions OIDC token, invalid login token |
| 403 | Repository outside `GITHUB_ORG`; app not installed on the repository; Actions token for a different repository or subject; ref or workflow not allowed; the developer has no push access |
| 500 | Signing the app JWT failed |
| 502 | GitHub failed: login token check, installation lookup, permission lookup or token minting |

For a login token the broker issues a token only if the developer has `write` or `admin` access
to the repository. For an Actions token both the `repository` and the `sub` claim must name the
requested repository, and any configured ref and workflow allowlists must match.

## `POST /token/actions`

Same request and response as `/token`, but a bearer token that is not shaped like a JWT gets 401
`only GitHub Actions OIDC tokens are accepted here`. Forward only this path on a public route.

## `GET /login-app`

```json
{"client_id": "<login app client ID>"}
```

## `GET /healthz`

200 while the process runs.

## `GET /readyz`

200 when GitHub accepts the app key (the broker calls `GET /app` with an app JWT, 3 second
timeout), else 503 `not ready`.

## `GET /metrics`

Prometheus exposition format; see [Metrics](../metrics/).
