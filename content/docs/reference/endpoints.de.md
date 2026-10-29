---
title: Endpunkte
weight: 4
---

| Methode und Pfad | Zweck | Zielgruppe |
| --- | --- | --- |
| `POST /token` | Agent-Token für ein Login-Token eines Entwicklers oder ein Actions-OIDC-Token | intern |
| `POST /token/actions` | Agent-Token nur für ein Actions-OIDC-Token | darf öffentlich sein |
| `GET /login-app` | Client-ID der Login-App | intern |
| `GET /healthz` | Liveness | Probes |
| `GET /readyz` | Readiness | Probes |
| `GET /metrics` | Prometheus-Metriken | Scraper |

## `POST /token` {#post-token}

Anfrage:

```http
POST /token
Authorization: Bearer <login token or Actions OIDC token>
Content-Type: application/json

{"repo": "my-org/my-repo"}
```

Das Bearer-Token bestimmt den Weg: Ein Token mit zwei Punkten ist ein GitHub-Actions-OIDC-Token,
alles andere ein User-Token der Login-App. Der Body ist auf 4096 Bytes begrenzt.

Antwort (200):

```json
{"token": "ghs_...", "expires_at": "2026-01-01T12:00:00Z", "permissions": {"contents": "write"}}
```

Das Token gilt für das eine Repository und lebt eine Stunde. Fehler sind Klartext-Bodies:

| Status | Ursache |
| --- | --- |
| 400 | Ungültiges JSON, oder `repo` ist nicht `owner/name` |
| 401 | Fehlendes Bearer-Token, ungültiges oder unlesbares Actions-OIDC-Token, ungültiges Login-Token |
| 403 | Repository außerhalb von `GITHUB_ORG`; App nicht auf dem Repository installiert; Actions-Token für ein anderes Repository oder einen anderen Subject; Ref oder Workflow nicht erlaubt; der Entwickler hat keinen Push-Zugriff |
| 500 | Signieren des App-JWT fehlgeschlagen |
| 502 | GitHub ist fehlgeschlagen: Prüfung des Login-Tokens, Installation-Lookup, Berechtigungsabfrage oder Ausstellen des Tokens |

Bei einem Login-Token stellt der Broker nur dann ein Token aus, wenn der Entwickler `write`- oder
`admin`-Zugriff auf das Repository hat. Bei einem Actions-Token müssen der Claim `repository` und
der Claim `sub` beide das angeforderte Repository nennen, und konfigurierte Positivlisten für Refs
und Workflows müssen passen.

## `POST /token/actions` {#post-tokenactions}

Gleiche Anfrage und Antwort wie `/token`, aber ein Bearer-Token, das nicht wie ein JWT aufgebaut
ist, bekommt 401 `only GitHub Actions OIDC tokens are accepted here`. Leiten Sie auf einer
öffentlichen Route nur diesen Pfad weiter.

## `GET /login-app` {#get-login-app}

```json
{"client_id": "<login app client ID>"}
```

## `GET /healthz` {#get-healthz}

200, solange der Prozess läuft.

## `GET /readyz` {#get-readyz}

200, wenn GitHub den App-Schlüssel akzeptiert (der Broker ruft `GET /app` mit einem App-JWT auf,
Timeout 3 Sekunden), sonst 503 `not ready`.

## `GET /metrics` {#get-metrics}

Prometheus-Exposition-Format; siehe [Metriken](../metrics/).
