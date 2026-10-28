# 12. Public repository in pflege-de-labs

- Status: accepted
- Date: 2026-10-28

## Context

The client scripts should live next to the broker and ship as release artifacts that the
`agent-token` Dev Container Feature downloads during the container build, without a GitHub login.
That needs a public repository. ADR 7 kept this repository private because it carried deployment
details: the internal broker hostname and the login app client ID.

## Decision

token-broker moves to a new public repository, `pflege-de-labs/token-broker`. Its history was
rewritten to replace deployment values with placeholders; deployment values live in cc-gitops and
in the org variables (ADR 8). The private `pflege-de/token-broker` is archived.

## Alternatives

- **Transfer the repository and rewrite its history in place:** GitHub keeps the head refs of
  existing pull requests, so the old commits would stay fetchable once public.
- **Keep it private and publish artifacts as public packages only:** splits source and
  artifacts across visibility settings (ADR 7).

## Consequences

- Image and chart move to `ghcr.io/pflege-de-labs/token-broker` and `ghcr.io/pflege-de-labs/charts`;
  deployments switch with the first release from this repository.
- Pull requests and issues before the move stay in the archived repository.
- Deployment values must not be committed here; workflow logs are public too, so the smoke
  test's broker URL is not set as a variable.
