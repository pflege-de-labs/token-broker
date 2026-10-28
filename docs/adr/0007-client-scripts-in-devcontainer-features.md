# 7. Client scripts in devcontainer-features

- Status: accepted; the private-repository premise is superseded by ADR 12
- Date: 2026-10-26

## Context

Every repository that runs an agent in a devcontainer needs the client scripts (`agent-token`,
the git credential helper, the `gh` wrapper, `agent-github-mcp`). They lived in this private
repository, so other repos copied them at a pinned commit and drifted. A Dev Container Feature
would ship them in one versioned package, but features are pulled from ghcr.io without a login,
so the feature, and the scripts it installs, must be public.

## Decision

The client scripts live in the public `pflege-de-labs/devcontainer-features`
(`src/agent-token/`), next to the future `agent-token` feature. This repository keeps the broker,
its chart and `agent-run`, which finds `agent-token` in `PATH`. Until the feature is published,
this repository's devcontainer fetches the scripts at a pinned commit.

## Alternatives

- **Keep them here and publish the feature from here:** the feature build would be public
  while its source is private, and other repos still could not read the scripts.
- **Make token-broker public:** exposes deployment details that have no reason to be public.

## Consequences

- The scripts contain no deployment values; broker URL and login app client ID stay
  configuration.
- Script changes need a devcontainer-features change and a bump of the pinned commit here.
- Developers using `agent-run` or `agent-token` on the host clone devcontainer-features.
