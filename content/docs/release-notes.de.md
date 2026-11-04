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

## Unreleased {#unreleased}

* Optionale Agent-Token-Scopes `workflows` und `actions`, angefordert mit `scope` in
  `POST /token` oder `AGENT_TOKEN_SCOPE` im Client und aktiviert mit `AGENT_SCOPES` (Chart
  `config.scopes`) und `ACTIONS_SCOPE_WORKFLOWS` (Chart `config.actionsOidc.scopeWorkflows`).
  Siehe [Scopes](../guides/scopes/).
* `agent-token --login` startet immer einen neuen Device Flow.
* Audit-Log und Token-Metriken tragen ein Attribut `scope`.

Auch diese Dokumentation ist versioniert: Wählen Sie im Menü **Versionen** die Version, die Sie
betreiben.
