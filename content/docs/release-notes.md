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

This documentation is versioned too: pick the version you run from the **Versions** menu.
