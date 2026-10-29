---
title: Helm-Values
weight: 5
---

Values des Charts `token-broker`, veröffentlicht unter
`oci://ghcr.io/pflege-de-labs/charts/token-broker`. Die maßgebliche Liste mit Kommentaren ist
[`values.yaml`](https://github.com/pflege-de-labs/token-broker/blob/main/charts/token-broker/values.yaml).

## Broker {#broker}

| Value | Standard | Bedeutung |
| --- | --- | --- |
| `replicaCount` | `2` | Zustandslos; ein zweites Replikat deckt Pod-Neustarts ab. |
| `image.repository` | `ghcr.io/pflege-de-labs/token-broker` | Image. |
| `image.tag` | `appVersion` des Charts | Image-Tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `imagePullSecrets`, `nameOverride`, `fullnameOverride` | leer | |
| `serviceAccount.create`, `.automount`, `.annotations`, `.name` | `true`, `false`, `{}`, generiert | Der Broker spricht nie mit der Kubernetes-API. |
| `podAnnotations`, `podLabels` | `{}` | |
| `podSecurityContext` | non-root `65532`, `fsGroup: 65532`, Seccomp `RuntimeDefault` | |
| `securityContext` | keine Rechteausweitung, Root-Dateisystem schreibgeschützt, alle Capabilities entfernt | |
| `service.type`, `service.port` | `ClusterIP`, `8080` | Bedient `/token`, die Probes und `/metrics`. |
| `resources` | `{}` | |
| `livenessProbe` | `GET /healthz` | |
| `readinessProbe` | `GET /readyz`, `timeoutSeconds: 5`, `periodSeconds: 15` | `/readyz` ruft GitHub auf, was länger als 1 Sekunde dauern kann. |
| `extraEnv` | `{}` | Zusätzliche Umgebungsvariablen. |
| `extraObjects` | `[]` | Zusätzliche Manifeste, die mit dem Release gerendert werden (über `tpl`), zum Beispiel ein `ExternalSecret`, das `existingSecret` liefert. |
| `nodeSelector`, `tolerations`, `affinity` | leer | |

## Konfiguration {#configuration}

| Value | Umgebungsvariable | Standard |
| --- | --- | --- |
| `config.appId` | `GITHUB_APP_ID` | Pflicht |
| `config.org` | `GITHUB_ORG` | Pflicht |
| `config.loginClientId` | `LOGIN_APP_CLIENT_ID` | Pflicht |
| `config.apiUrl` | `GITHUB_API_URL` | leer: `https://api.github.com` |
| `config.agentPermissions` | `AGENT_PERMISSIONS` | `{}`: die Standardmenge |
| `config.actionsOidc.audience` | `ACTIONS_OIDC_AUDIENCE` | `token-broker` |
| `config.actionsOidc.issuer` | `ACTIONS_OIDC_ISSUER` | leer: Aussteller von GitHub |
| `config.actionsOidc.allowedRefs` | `ACTIONS_ALLOWED_REFS` | `[]` |
| `config.actionsOidc.allowedWorkflows` | `ACTIONS_ALLOWED_WORKFLOWS` | `[]` |

`config.agentPermissions` ist eine Map, zum Beispiel
`{contents: write, pull_requests: write, issues: write, metadata: read, actions: write}`. Listen Sie
die vollständige Menge auf; die Agent-App muss alle erhalten haben.

## Secret {#secret}

| Value | Standard | Bedeutung |
| --- | --- | --- |
| `existingSecret` | leer | Name eines Secrets mit den Schlüsseln `private-key.pem` und `login-client-secret`. Ist es gesetzt, rendert das Chart kein Secret und ignoriert `secret`. |
| `secret.privateKey`, `secret.loginClientSecret` | leer | Wird in ein vom Chart verwaltetes Secret gerendert, wenn `existingSecret` leer ist. |

## Erreichbarkeit {#exposure}

| Value | Standard | Bedeutung |
| --- | --- | --- |
| `ingress.enabled` | `false` | Zugriff von Entwicklern und Runnern auf `/token`. Halten Sie ihn möglichst intern. Außerdem `className`, `annotations`, `hosts`, `tls`. |
| `httpRoute.enabled` | `false` | Dasselbe über eine Gateway-API-`HTTPRoute`. Außerdem `annotations`, `parentRefs`, `hostnames`, `rules`. |
| `actionsRoute.enabled` | `false` | Öffentliche Route für GitHub-gehostete Runner: leitet nur `POST <path>` an `/token/actions` weiter. Braucht `parentRefs` (ein Gateway mit Internetzugang). |
| `actionsRoute.path` | `/token/actions` | Öffentlicher Pfad, auf `/token/actions` umgeschrieben; setzen Sie ein Präfix, wenn der Host geteilt wird. |
| `actionsRoute.hostnames`, `.annotations`, `.labels` | leer | |

## Metriken {#metrics}

| Value | Standard | Bedeutung |
| --- | --- | --- |
| `metrics.serviceMonitor.enabled` | `false` | Rendert einen `ServiceMonitor`, der `/metrics` abruft. Braucht die CRDs des Prometheus Operators. |
| `metrics.serviceMonitor.interval`, `.scrapeTimeout` | leer | |
| `metrics.serviceMonitor.extraLabels`, `.annotations` | `{}` | |
| `metrics.serviceMonitor.relabelings`, `.metricRelabelings` | `[]` | |
