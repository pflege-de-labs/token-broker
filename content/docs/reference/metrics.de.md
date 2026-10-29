---
title: Metriken
weight: 6
---

Der Broker exportiert Prometheus-Metriken unter `GET /metrics`. Die Instrumente heißen nach
OpenTelemetry-Art, und der Prometheus-Exporter macht aus jedem Namen Unterstriche und ergänzt
Einheiten- und Typ-Suffixe. Im Chart rendert `metrics.serviceMonitor.enabled` einen
`ServiceMonitor`.

| OpenTelemetry | Prometheus | Typ | Einheit |
| --- | --- | --- | --- |
| `broker.token.requests` | `broker_token_requests_total` | Counter | |
| `broker.token.duration` | `broker_token_duration_seconds` | Histogramm (`_bucket`, `_sum`, `_count`) | Sekunden |

Beide tragen zwei Attribute:

| Attribut | Werte |
| --- | --- |
| `outcome` | `issued`, `unauthenticated`, `bad_request`, `denied`, `error` |
| `via` | `actions` (Actions-OIDC-Token), `device` (Login-Token), `unknown` (abgewiesen, bevor der Aufrufer bekannt ist) |

`broker.token.requests` zählt Token-Anfragen nach Ergebnis. `broker.token.duration` erfasst, wie
lange sie dauerten. Anfragen an `/token/actions` ohne ein Bearer-Token in JWT-Form zählen als
`unauthenticated` mit `via` `actions` und erfassen keine Dauer.

Der Exporter ergänzt außerdem `otel_scope_*`-Labels und eine Serie `target_info`, und die Go-Runtime-
und Prozessmetriken der Standard-Prometheus-Registry werden mit ausgeliefert.
