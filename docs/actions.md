# Agent tokens in GitHub Actions

Workflows exchange their OIDC token for an agent token. Two setups, chosen per org or repo by
Actions variables:

| | Runner | Broker URL | When |
|---|---|---|---|
| **B (default)** | GitHub-hosted | public `https://<public broker route>/token/actions` | the job needs nothing internal |
| **A** | self-hosted `internal` | internal `https://token-broker.internal/token/actions` | the job also needs internal systems |

For A, set `AGENT_RUNNER=internal` and `TOKEN_BROKER_URL=<internal URL>` as repo or org variables
(org variables live in github-ops). Internal runner capacity is limited, so B stays the default.

The public route forwards only `POST /token-broker/token/actions`. That endpoint accepts Actions
OIDC tokens and nothing else; developer logins, probes and metrics stay internal.

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
          TOKEN_BROKER_URL: ${{ vars.TOKEN_BROKER_URL || 'https://<public broker route>/token/actions' }}
        run: |
          oidc=$(curl -fsS -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=token-broker" | jq -r .value)
          token=$(curl -fsS "$TOKEN_BROKER_URL" -H "Authorization: Bearer $oidc" \
            -d "{\"repo\":\"$GITHUB_REPOSITORY\"}" | jq -r .token)
          echo "::add-mask::$token"
          echo "token=$token" >> "$GITHUB_OUTPUT"
      - uses: anthropics/claude-code-action@v1
        with:
          github_token: ${{ steps.agent.outputs.token }}
```

The token only covers the repo the workflow runs in: the broker requires both the `repository` claim and `sub` (classic `repo:owner/name:…` or immutable `repo:owner@ID/name@ID:…`, IDs checked against the signed ID claims) to name the requested repo. It expires after 1h.
