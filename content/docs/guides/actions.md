---
title: Get agent tokens in GitHub Actions
weight: 2
---

Workflows exchange their OIDC token for an agent token. Where the broker is reachable decides
which runners can use it.

| Runner | Broker endpoint | Chart |
| --- | --- | --- |
| GitHub-hosted | public `POST <public URL>` forwarded to `/token/actions` | `actionsRoute` |
| self-hosted with internal network access | internal `POST <internal URL>/token/actions` (or `/token`) | `httpRoute` or the Service |

`/token/actions` accepts Actions OIDC tokens and nothing else, so `actionsRoute` can be public: it
forwards exactly one path, `POST` only, and developer logins, probes and metrics stay internal.

## Workflow

Workflows pick runner and URL from Actions variables, so one workflow serves both setups:

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
          TOKEN_BROKER_URL: ${{ vars.TOKEN_BROKER_URL }}
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

The audience must match `ACTIONS_OIDC_AUDIENCE` (default `token-broker`). Here
`TOKEN_BROKER_URL` is the organization's Actions variable holding the public `/token/actions`
URL. It is not the container variable of the same name; see
[Dev Container](../../getting-started/devcontainer/).

The token covers only the repository the workflow runs in: the broker requires both the
`repository` claim and `sub` to name the requested repository. `sub` is either the classic
`repo:owner/name:…` or the immutable `repo:owner@ID/name@ID:…`, whose IDs are checked against the
signed ID claims. The token expires after one hour.

## Restrict refs and workflows

By default any workflow in a repository the app is installed on may get a token. Two chart values
narrow that. Both are lists of patterns where `*` matches any characters, including `/`:

```yaml
config:
  actionsOidc:
    # `ref` claim: only the default branch and release tags
    allowedRefs: [refs/heads/main, "refs/tags/v*"]
    # `job_workflow_ref` claim: only a shared agent workflow
    allowedWorkflows: ["my-org/agent-workflows/.github/workflows/agent.yml@*"]
```

A request must match one pattern of each configured list. Empty lists apply no restriction. Pull
request runs carry `ref: refs/pull/<n>/merge`, so `allowedRefs` without `refs/pull/*` blocks
agents on pull requests.
