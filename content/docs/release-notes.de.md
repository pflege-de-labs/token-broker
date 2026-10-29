---
title: Versionshinweise
weight: 99
---

Releases sind Tags `vX.Y.Z` auf `main`. Die
[Release-Seite](https://github.com/pflege-de-labs/token-broker/releases) listet, was sich in jedem
geändert hat, und enthält die Assets: Das signierte Container-Image wird unter
`ghcr.io/pflege-de-labs/token-broker` veröffentlicht, und jedes Release hängt die Client-Skripte als
`agent-token-<version>.tar.gz` mit einer `checksums.txt` an.

Das Helm-Chart wird separat versioniert und unter `oci://ghcr.io/pflege-de-labs/charts`
veröffentlicht, wenn sich `version` in seiner `Chart.yaml` auf `main` ändert.

Auch diese Dokumentation ist versioniert: Wählen Sie im Menü **Versionen** die Version, die Sie
betreiben.
