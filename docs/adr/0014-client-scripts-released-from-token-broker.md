# 14. Client scripts released from token-broker

- Status: accepted; location of the scripts amended by ADR 15
- Date: 2026-10-29

## Context

The client scripts (`agent-token`, its git credential helper, the `gh` wrapper, `agent-github-mcp`,
`agent-commit`) lived in the agent-token devcontainer feature. They speak the broker's API, so a
broker change (e.g. `GET /login-app`, ADR 11) needed PRs in two repos, and anyone outside a
devcontainer had to clone the feature repo to get them.

## Decision

The scripts live in `client/` of this repo. Every `v*` release attaches them as
`agent-token-<version>.tar.gz` plus `checksums.txt`. The devcontainer feature only installs: it
downloads a pinned release and checks a sha256 pinned next to that version in the feature.

## Alternatives

- **Keep them in the feature:** two repos per client-visible broker change.
- **Feature installs the latest release:** container rebuilds pick up new scripts unreviewed.
- **Feature checks the release's `checksums.txt` only, or a cosign signature:** the first catches
  corruption but not a tampered release; the second adds a cosign download to every build.

## Consequences

- Scripts and broker change and release together; a script change reaches devcontainers with the
  next release and a feature PR that bumps version and sha256.
- The release workflow builds the tarball; workflow changes need a human commit (the agent token
  has no `workflows` permission).
