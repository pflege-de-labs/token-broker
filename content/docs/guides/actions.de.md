---
title: Agent-Tokens in GitHub Actions holen
weight: 2
---

Workflows tauschen ihr OIDC-Token gegen ein Agent-Token. Wo der Broker erreichbar ist, entscheidet,
welche Runner ihn nutzen können.

| Runner | Broker-Endpunkt | Chart |
| --- | --- | --- |
| GitHub-gehostet | öffentlich `POST <public base URL>/token/actions` | `actionsRoute` |
| selbst gehostet mit Zugang zum internen Netz | intern `POST <internal URL>/token/actions` (oder `/token`) | `httpRoute` oder der Service |

`/token/actions` akzeptiert Actions-OIDC-Tokens und sonst nichts, deshalb kann `actionsRoute`
öffentlich sein: Sie leitet genau einen Pfad weiter, nur `POST`, und Entwickler-Logins, Probes und
Metriken bleiben intern.

## Workflow {#workflow}

Workflows wählen Runner und Broker-URL aus Actions-Variablen, sodass ein Workflow beide Setups bedient:

```yaml
jobs:
  agent:
    runs-on: ${{ vars.AGENT_RUNNER || 'ubuntu-latest' }}
    permissions:
      id-token: write
      contents: read
    steps:
      - id: agent
        env:
          BROKER: ${{ vars.AGENT_TOKEN_BROKER_ACTIONS_URL }}
        run: |
          oidc=$(curl -fsS -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=token-broker" | jq -r .value)
          token=$(curl -fsS "$BROKER/token/actions" -H "Authorization: Bearer $oidc" \
            -d "{\"repo\":\"$GITHUB_REPOSITORY\"}" | jq -r .token)
          echo "::add-mask::$token"
          echo "token=$token" >> "$GITHUB_OUTPUT"
      - uses: anthropics/claude-code-action@v1
        with:
          github_token: ${{ steps.agent.outputs.token }}
```

Die Audience muss zu `ACTIONS_OIDC_AUDIENCE` passen (Standard `token-broker`).
`AGENT_TOKEN_BROKER_ACTIONS_URL` ist die Actions-Variable der Organisation mit der Basis-URL des
Brokers für Workflows: die öffentliche Route für GitHub-gehostete Runner oder die interne URL für
selbst gehostete Runner. Der Workflow hängt `/token/actions` an. `AGENT_TOKEN_BROKER_URL` ist die
interne URL für Entwicklerrechner ([Dev Container](../../getting-started/devcontainer/)); deren
Anmeldungen bedient die öffentliche Route nicht.

Das Token gilt nur für das Repository, in dem der Workflow läuft: Der Broker verlangt, dass der
Claim `repository` und `sub` beide das angeforderte Repository nennen. `sub` ist entweder die
klassische Form `repo:owner/name:…` oder die unveränderliche Form `repo:owner@ID/name@ID:…`, deren
IDs gegen die signierten ID-Claims geprüft werden. Das Token läuft nach einer Stunde ab.

## Refs und Workflows einschränken {#restrict-refs-and-workflows}

Standardmäßig darf jeder Workflow in einem Repository, auf dem die App installiert ist, ein Token
bekommen. Zwei Chart-Values schränken das ein. Beide sind Listen von Mustern, in denen `*` beliebige
Zeichen einschließlich `/` abdeckt:

```yaml
config:
  actionsOidc:
    # `ref` claim: only the default branch and release tags
    allowedRefs: [refs/heads/main, "refs/tags/v*"]
    # `job_workflow_ref` claim: only a shared agent workflow
    allowedWorkflows: ["my-org/agent-workflows/.github/workflows/agent.yml@*"]
```

Eine Anfrage muss je einem Muster jeder konfigurierten Liste entsprechen. Leere Listen schränken
nichts ein. Läufe für Pull Requests tragen `ref: refs/pull/<n>/merge`, daher sperrt `allowedRefs`
ohne `refs/pull/*` Agenten in Pull Requests.
