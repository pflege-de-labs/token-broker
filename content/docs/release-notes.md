---
title: Release notes
weight: 99
---

Releases are tags `vX.Y.Z` on `main`. The
[releases page](https://github.com/pflege-de-labs/token-broker/releases) lists what changed in each
and carries the assets: the signed container image is published to
`ghcr.io/pflege-de-labs/token-broker`, and every release attaches the client scripts as
`agent-token-<version>.tar.gz` with a `checksums.txt`.

The Helm chart is versioned separately and published to `oci://ghcr.io/pflege-de-labs/charts`
when `version` in its `Chart.yaml` changes on `main`.

## Unreleased

* Opt-in agent token scopes `workflows` and `actions`, requested with `scope` in `POST /token` or
  `AGENT_TOKEN_SCOPE` in the client, and enabled with `AGENT_SCOPES` (chart `config.scopes`) and
  `ACTIONS_SCOPE_WORKFLOWS` (chart `config.actionsOidc.scopeWorkflows`). See
  [Scopes](../guides/scopes/).
* `agent-token --login` always starts a new device flow.
* The audit log and the token metrics carry a `scope` attribute.

This documentation is versioned too: pick the version you run from the **Versions** menu.
