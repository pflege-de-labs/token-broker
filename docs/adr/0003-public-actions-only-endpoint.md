# 3. Public endpoint for Actions OIDC only

- Status: accepted
- Date: 2026-10-23

## Context

GitHub never calls the broker; only developers and workflows do. A fully internal broker would
force agent workflows onto self-hosted runners, whose capacity is limited and which are meant
for jobs that need internal systems. GitHub-hosted runners come from large, changing cloud IP
ranges, so an IP allowlist cannot protect a public endpoint.

## Decision

The broker has a separate endpoint, `POST /token/actions`, that accepts Actions OIDC tokens and
nothing else. Only that path and method is exposed publicly (chart value `actionsRoute`), with
a gateway rate limit; developer logins, probes and metrics stay on the internal route.
GitHub-hosted runners with the public route are the default; self-hosted runners with the
internal URL remain available per repository or org through the Actions variables
`AGENT_RUNNER` and `TOKEN_BROKER_URL`.

## Alternatives

- **Fully internal broker, agent workflows on self-hosted runners only:** no public surface, but
  binds every agent run to scarce internal capacity.
- **Public `/token`:** would expose the device-flow path and invite device-code phishing.
- **IP allowlist for GitHub-hosted runners:** thousands of changing ranges.

## Consequences

- The public endpoint is protected by OIDC verification and rate limiting only. Forged tokens
  with unknown key IDs make the broker refetch GitHub's keys, bounded by the rate limit.
- The deployment must exempt this one route from any gateway-wide IP allowlist.
