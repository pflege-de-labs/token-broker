---
title: Workflows mit Scopes bearbeiten oder ausführen
weight: 3
---

Agent-Tokens können committen, pushen, Pull Requests öffnen und an Issues arbeiten. Zwei optionale
Scopes fügen je eine Berechtigung hinzu, jeweils für ein einzelnes Token
([ADR 16](https://github.com/pflege-de-labs/token-broker/blob/main/docs/adr/0016-agent-token-scopes.md)):

| Scope | Fügt hinzu | Wofür |
| --- | --- | --- |
| `default` | nichts | alles andere |
| `workflows` | `workflows: write` | Änderungen unter `.github/workflows/` pushen |
| `actions` | `actions: write` | `workflow_dispatch`, Jobs erneut ausführen |

Kein Token hat beides: Der Broker startet nicht, wenn ein Scope beides enthielte.

## Aktivieren {#enable}

1. Erteilen Sie der Agent-App die Berechtigung (**Workflows: Read and write**,
   **Actions: Read and write**) und akzeptieren Sie sie in jeder Installation
   ([GitHub-Apps einrichten](../github-apps/)). GitHub verweigert Tokens für Installationen, die
   nicht akzeptiert haben.
2. Setzen Sie die Chart-Werte:

   ```yaml
   config:
     scopes: [workflows]          # AGENT_SCOPES
     actionsOidc:
       # Workflows that may request a scope (ACTIONS_SCOPE_WORKFLOWS); empty: none.
       scopeWorkflows: ["acme/app/.github/workflows/release.yml@refs/heads/main"]
   ```

   Enthält `agentPermissions` den Eintrag `actions: write`, entfernen Sie ihn und aktivieren Sie
   stattdessen den Scope `actions`. Sonst hätte der Scope `workflows` beides, und der Broker
   startet nicht.

## Verwenden {#use}

Entwickler: Melden Sie sich neu an und fordern Sie den Scope innerhalb von 10 Minuten an. Der
Broker prüft, dass der Login so aktuell ist, damit ein Agent sich mit einem zwischengespeicherten
Login nicht selbst höherstufen kann.

```sh
agent-token --login                              # in Claude Code: ! agent-token --login
AGENT_TOKEN_SCOPE=workflows agent-commit -m "ci: …"
AGENT_TOKEN_SCOPE=actions agent-gh run rerun 1234 --failed   # `gh` im Devcontainer
```

Das erhöhte Token wird pro Scope für seine eine Stunde zwischengespeichert. Aufrufe ohne
`AGENT_TOKEN_SCOPE` nutzen weiter das Default-Token. `AGENT_TOKEN_SCOPE=workflows agent-run`
führt eine ganze Sitzung mit dem Scope aus; sie endet nach einer Stunde, weil die Erneuerung einen
weiteren frischen Login braucht.

Workflows: Fügen Sie `"scope":"workflows"` zum Request-Body hinzu. Nur Workflows, die zu
`scopeWorkflows` passen, erhalten ihn. Siehe [Agent-Tokens in GitHub Actions holen](../actions/).

## Bevor Sie `workflows` für ein Repository aktivieren {#before-enabling-workflows-on-a-repository}

Ein gepushter Workflow läuft über seinen `push`- oder `pull_request`-Trigger. Er braucht kein
`actions: write`. Ein Agent mit `workflows` kann also Code ausführen, den er selbst geschrieben
hat, mit allem, was dieser Branch erreicht. Machen Sie Agent-Branches zuerst unprivilegiert:

* Secrets nur in **Environments**, deren Deployment-Branch-Richtlinie nur geschützte Branches
  zulässt, mit erforderlichen Reviewern für Produktion. Keine Repository- oder
  Organisations-Secrets.
* `ACTIONS_ALLOWED_REFS` auf geschützte Branches beschränkt, damit ein Workflow auf einem
  Agent-Branch selbst kein Agent-Token bekommt.
* Cloud-OIDC-Vertrauensrichtlinien an einen `ref` oder ein `environment` gebunden, nicht nur an
  das Repository.
* Standardberechtigungen des `GITHUB_TOKEN` der Organisation schreibgeschützt; **Allow GitHub
  Actions to create and approve pull requests** aus.
* Selbst gehostete Runner-Gruppen auf ausgewählte Workflows auf geschützten Branches beschränkt.
* `.github/workflows/` gehört in `CODEOWNERS` einem menschlichen Team. Code-Owner-Review ist
  bereits Pflicht ([Review-Regeln setzen](../review-rules/)).

## Auslösen ohne `actions` {#triggering-without-actions}

`repository_dispatch` braucht nur `contents: write`, das jedes Agent-Token hat, und führt die
Version eines Workflows aus dem Default-Branch aus. Repositories, in denen Agenten geprüfte
Workflows starten sollen, können `on: repository_dispatch` ergänzen, statt `actions` zu
aktivieren. Ein solcher Workflow darf keinen Ref aus `client_payload` auschecken, solange Secrets
verfügbar sind.

`actions: write` erlaubt dem Agent außerdem, Runs und Logs abzubrechen und zu löschen, Workflows
zu deaktivieren und Caches zu löschen.
