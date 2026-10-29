---
title: Broker-Konfiguration
weight: 3
---

Der Broker liest seine Konfiguration aus Umgebungsvariablen. Das Helm-Chart erzeugt sie aus seinen
[Values](../helm-values/).

| Variable | Chart-Value | Standard | Bedeutung |
| --- | --- | --- | --- |
| `GITHUB_APP_ID` | `config.appId` | | App-ID der Agent-App. Pflicht. |
| `GITHUB_APP_PRIVATE_KEY_FILE` | Secret-Schlüssel `private-key.pem` | | Pfad zum privaten Schlüssel der Agent-App. Pflicht. |
| `GITHUB_ORG` | `config.org` | | Kommagetrennte Organisationen; nur deren Repositories bekommen Tokens. Pflicht. |
| `LOGIN_APP_CLIENT_ID` | `config.loginClientId` | | Client-ID der Login-App. Pflicht. |
| `LOGIN_APP_CLIENT_SECRET` | Secret-Schlüssel `login-client-secret` | | Client-Secret der Login-App. Pflicht. |
| `ACTIONS_OIDC_AUDIENCE` | `config.actionsOidc.audience` | `token-broker` | Audience, die Workflows anfordern müssen. |
| `ACTIONS_OIDC_ISSUER` | `config.actionsOidc.issuer` | `https://token.actions.githubusercontent.com` | Aussteller der Actions-OIDC-Tokens. |
| `ACTIONS_ALLOWED_REFS` | `config.actionsOidc.allowedRefs` | leer: beliebig | Kommagetrennte Glob-Muster für den Claim `ref`. |
| `ACTIONS_ALLOWED_WORKFLOWS` | `config.actionsOidc.allowedWorkflows` | leer: beliebig | Kommagetrennte Glob-Muster für den Claim `job_workflow_ref`. |
| `AGENT_PERMISSIONS` | `config.agentPermissions` | `contents:write,pull_requests:write,issues:write,metadata:read` | Berechtigungen jedes Agent-Tokens als `name:level,...`, Level `read` oder `write`. |
| `LISTEN_ADDR` | | `:8080` | Listen-Adresse. |
| `GITHUB_API_URL` | `config.apiUrl` | `https://api.github.com` | Basis-URL der GitHub-API. |

In Glob-Mustern steht `*` für beliebige Zeichen einschließlich `/`. `AGENT_PERMISSIONS` ersetzt die
Standardmenge: Listen Sie alle Berechtigungen auf, und die Agent-App muss jede davon erhalten
haben, sonst verweigert GitHub das Token. Ein ungültiger Eintrag stoppt den Broker beim Start.

Der Broker braucht ausgehenden Zugriff nur auf `api.github.com` und
`token.actions.githubusercontent.com`. Er protokolliert jedes ausgestellte und abgelehnte Token als
strukturierte Logzeile mit Aufrufer und Repository.
