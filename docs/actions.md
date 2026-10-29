# Agent tokens in GitHub Actions

Workflows exchange their OIDC token for an agent token. Where the broker is reachable decides
which runners can use it:

| Runner | Broker endpoint | Chart |
|---|---|---|
| GitHub-hosted | public `POST <public base URL>/token/actions` | `actionsRoute` |
| self-hosted with internal network access | internal `POST <internal URL>/token/actions` (or `/token`) | `httpRoute` or the Service |

`/token/actions` accepts Actions OIDC tokens and nothing else, so `actionsRoute` can be public:
it forwards exactly one path, POST only, and developer logins, probes and metrics stay internal.
Deployment specifics (URLs, runner labels, variables) live with the deployment, not here.

Workflows pick runner and broker from Actions variables, so one workflow serves both setups.
`AGENT_TOKEN_BROKER_ACTIONS_URL` is a base URL (the public one, or the internal one for
self-hosted runners); the workflow appends `/token/actions`. `AGENT_TOKEN_BROKER_URL` is the
internal URL for developer machines, not for workflows.

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

The token only covers the repo the workflow runs in: the broker requires both the `repository` claim and `sub` (classic `repo:owner/name:…` or immutable `repo:owner@ID/name@ID:…`, IDs checked against the signed ID claims) to name the requested repo. It expires after 1h.

## Restricting refs and workflows (optional)

By default any workflow in a repo the app is installed on may get a token. Two chart values
narrow that; both are lists of patterns where `*` matches any characters, including `/`:

```yaml
config:
  actionsOidc:
    # `ref` claim: only the default branch and release tags
    allowedRefs: [refs/heads/main, "refs/tags/v*"]
    # `job_workflow_ref` claim: only a shared agent workflow
    allowedWorkflows: ["my-org/agent-workflows/.github/workflows/agent.yml@*"]
```

A request must match one pattern of each configured list. Empty lists apply no restriction.
Pull request runs carry `ref: refs/pull/<n>/merge`, so `allowedRefs` without `refs/pull/*` blocks agents on PRs.
