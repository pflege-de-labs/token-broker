---
title: Broker configuration
weight: 3
---

The broker reads its configuration from environment variables. The Helm chart renders them from
its [values](../helm-values/).

| Variable | Chart value | Default | Meaning |
| --- | --- | --- | --- |
| `GITHUB_APP_ID` | `config.appId` | | App ID of the agent app. Required. |
| `GITHUB_APP_PRIVATE_KEY_FILE` | Secret key `private-key.pem` | | Path to the agent app's private key. Required. |
| `GITHUB_ORG` | `config.org` | | Comma-separated organizations; only their repositories get tokens. Required. |
| `LOGIN_APP_CLIENT_ID` | `config.loginClientId` | | Client ID of the login app. Required. |
| `LOGIN_APP_CLIENT_SECRET` | Secret key `login-client-secret` | | Client secret of the login app. Required. |
| `ACTIONS_OIDC_AUDIENCE` | `config.actionsOidc.audience` | `token-broker` | Audience workflows must request. |
| `ACTIONS_OIDC_ISSUER` | `config.actionsOidc.issuer` | `https://token.actions.githubusercontent.com` | Issuer of Actions OIDC tokens. |
| `ACTIONS_ALLOWED_REFS` | `config.actionsOidc.allowedRefs` | empty: any | Comma-separated glob patterns for the `ref` claim. |
| `ACTIONS_ALLOWED_WORKFLOWS` | `config.actionsOidc.allowedWorkflows` | empty: any | Comma-separated glob patterns for the `job_workflow_ref` claim. |
| `AGENT_PERMISSIONS` | `config.agentPermissions` | `contents:write,pull_requests:write,issues:write,metadata:read` | Permissions of every agent token, as `name:level,...`, level `read` or `write`. |
| `AGENT_SCOPES` | `config.scopes` | empty: none | Comma-separated opt-in scopes clients may request: `workflows`, `actions`. See [Scopes](../../guides/scopes/). |
| `ACTIONS_SCOPE_WORKFLOWS` | `config.actionsOidc.scopeWorkflows` | empty: none | Comma-separated glob patterns for the `job_workflow_ref` claim of workflows that may request a scope. |
| `LISTEN_ADDR` | | `:8080` | Listen address. |
| `GITHUB_API_URL` | `config.apiUrl` | `https://api.github.com` | GitHub API base URL. |

In glob patterns `*` matches any characters, including `/`. `AGENT_PERMISSIONS` replaces the
default set: list all permissions, and the agent app must have been granted each of them, or
GitHub refuses the token. An invalid entry stops the broker at start.

`workflows` adds `workflows: write` and `actions` adds `actions: write` to the `AGENT_PERMISSIONS`
set. The agent app must be granted each permission a scope adds. The broker refuses to start if
any enabled scope would hold `workflows` and `actions: write` together; move `actions: write` from
`AGENT_PERMISSIONS` to the `actions` scope before you enable `workflows`.

The broker needs outbound access to `api.github.com` and `token.actions.githubusercontent.com`
only. It logs every issued and denied token as a structured log line with the caller and the
repository.
