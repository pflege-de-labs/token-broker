# 6. One broker for all company orgs

- Status: accepted
- Date: 2026-10-26

## Context

The company's repositories live in several GitHub orgs (pflege-de, pflege-de-labs, webcarelbj).
Agents should work in all of them. The broker accepted one org only. All orgs belong to the same
company, and developers reach the internal `/token` route via VPN.

## Decision

One broker and one agent app (`pflege-de-agent`) serve all orgs. `GITHUB_ORG` takes a
comma-separated list; the owner check ignores case. Installation, write-access and OIDC checks
already work per repository and stay unchanged.

## Alternatives

- **One broker and one agent app per org:** separate keys and audit logs per org, at the cost
  of one deployment and two apps per org. Worth it only for orgs of other companies.

## Consequences

- The agent app is public so other orgs can install it; tokens still need the broker's key.
- Each org must install the agent app and require code owner reviews on its repos (ADR 4);
  github-ops does this per org.
