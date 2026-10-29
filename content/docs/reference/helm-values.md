---
title: Helm values
weight: 5
---

Values of the `token-broker` chart, published to `oci://ghcr.io/pflege-de-labs/charts/token-broker`.
The authoritative list with comments is
[`values.yaml`](https://github.com/pflege-de-labs/token-broker/blob/main/charts/token-broker/values.yaml).

## Broker

| Value | Default | Meaning |
| --- | --- | --- |
| `replicaCount` | `2` | Stateless; a second replica covers pod restarts. |
| `image.repository` | `ghcr.io/pflege-de-labs/token-broker` | Image. |
| `image.tag` | chart `appVersion` | Image tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `imagePullSecrets`, `nameOverride`, `fullnameOverride` | empty | |
| `serviceAccount.create`, `.automount`, `.annotations`, `.name` | `true`, `false`, `{}`, generated | The broker never talks to the Kubernetes API. |
| `podAnnotations`, `podLabels` | `{}` | |
| `podSecurityContext` | non-root `65532`, `fsGroup: 65532`, `RuntimeDefault` seccomp | |
| `securityContext` | no privilege escalation, read-only root filesystem, drop all capabilities | |
| `service.type`, `service.port` | `ClusterIP`, `8080` | Serves `/token`, the probes and `/metrics`. |
| `resources` | `{}` | |
| `livenessProbe` | `GET /healthz` | |
| `readinessProbe` | `GET /readyz`, `timeoutSeconds: 5`, `periodSeconds: 15` | `/readyz` calls GitHub, which can take longer than 1 second. |
| `extraEnv` | `{}` | Additional environment variables. |
| `extraObjects` | `[]` | Extra manifests rendered with the release (run through `tpl`), for example an `ExternalSecret` providing `existingSecret`. |
| `nodeSelector`, `tolerations`, `affinity` | empty | |

## Configuration

| Value | Environment variable | Default |
| --- | --- | --- |
| `config.appId` | `GITHUB_APP_ID` | required |
| `config.org` | `GITHUB_ORG` | required |
| `config.loginClientId` | `LOGIN_APP_CLIENT_ID` | required |
| `config.apiUrl` | `GITHUB_API_URL` | empty: `https://api.github.com` |
| `config.agentPermissions` | `AGENT_PERMISSIONS` | `{}`: the default set |
| `config.actionsOidc.audience` | `ACTIONS_OIDC_AUDIENCE` | `token-broker` |
| `config.actionsOidc.issuer` | `ACTIONS_OIDC_ISSUER` | empty: GitHub's issuer |
| `config.actionsOidc.allowedRefs` | `ACTIONS_ALLOWED_REFS` | `[]` |
| `config.actionsOidc.allowedWorkflows` | `ACTIONS_ALLOWED_WORKFLOWS` | `[]` |

`config.agentPermissions` is a map, for example
`{contents: write, pull_requests: write, issues: write, metadata: read, actions: write}`. List the
full set; the agent app must be granted all of them.

## Secret

| Value | Default | Meaning |
| --- | --- | --- |
| `existingSecret` | empty | Name of a Secret with the keys `private-key.pem` and `login-client-secret`. When set, the chart renders no Secret and ignores `secret`. |
| `secret.privateKey`, `secret.loginClientSecret` | empty | Rendered into a chart-managed Secret when `existingSecret` is empty. |

## Exposure

| Value | Default | Meaning |
| --- | --- | --- |
| `ingress.enabled` | `false` | Developer and runner access to `/token`. Keep it internal where possible. Also `className`, `annotations`, `hosts`, `tls`. |
| `httpRoute.enabled` | `false` | The same via a Gateway API `HTTPRoute`. Also `annotations`, `parentRefs`, `hostnames`, `rules`. |
| `actionsRoute.enabled` | `false` | Public route for GitHub-hosted runners: forwards only `POST <path>` to `/token/actions`. Needs `parentRefs` (an internet-facing Gateway). |
| `actionsRoute.path` | `/token/actions` | Public path, rewritten to `/token/actions`; set a prefix when the host is shared. |
| `actionsRoute.hostnames`, `.annotations`, `.labels` | empty | |

## Metrics

| Value | Default | Meaning |
| --- | --- | --- |
| `metrics.serviceMonitor.enabled` | `false` | Renders a `ServiceMonitor` that scrapes `/metrics`. Needs the Prometheus Operator CRDs. |
| `metrics.serviceMonitor.interval`, `.scrapeTimeout` | empty | |
| `metrics.serviceMonitor.extraLabels`, `.annotations` | `{}` | |
| `metrics.serviceMonitor.relabelings`, `.metricRelabelings` | `[]` | |
