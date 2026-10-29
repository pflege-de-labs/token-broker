---
title: Metrics
weight: 6
---

The broker exports Prometheus metrics at `GET /metrics`. Instruments are named the OpenTelemetry
way, and the Prometheus exporter turns each name into underscores and adds unit and type
suffixes. In the chart, `metrics.serviceMonitor.enabled` renders a `ServiceMonitor`.

| OpenTelemetry | Prometheus | Type | Unit |
| --- | --- | --- | --- |
| `broker.token.requests` | `broker_token_requests_total` | counter | |
| `broker.token.duration` | `broker_token_duration_seconds` | histogram (`_bucket`, `_sum`, `_count`) | seconds |

Both carry two attributes:

| Attribute | Values |
| --- | --- |
| `outcome` | `issued`, `unauthenticated`, `bad_request`, `denied`, `error` |
| `via` | `actions` (Actions OIDC token), `device` (login token), `unknown` (rejected before the caller is known) |

`broker.token.requests` counts token requests by outcome. `broker.token.duration` records how long
they took. Requests to `/token/actions` without a JWT-shaped bearer token count as
`unauthenticated` via `actions` and record no duration.

The exporter also adds `otel_scope_*` labels and a `target_info` series, and the default
Prometheus registry's Go runtime and process metrics are served alongside.
