# token-broker

Gives coding agents (e.g. Claude Code) their own GitHub identity instead of a developer's.
Developers and GitHub Actions workflows exchange proof of who they are for a short-lived token
of a dedicated **agent GitHub App**. Agent commits and PRs show up as `<app>[bot]` and need a
human review, and developer credentials never reach the agent.

## Features

- **Narrow tokens:** one repository, one hour, contents, pull request and issue access only.
- **Developer login via device flow** with a permission-less login app; a token only for repos
  the developer has write access to.
- **GitHub Actions via OIDC:** `POST /token/actions`, safe to expose publicly, with optional
  ref and workflow allowlists.
- **Scoped to one org** and to repos the agent app is installed on.
- **Private key stays in the broker;** agents and workstations never see it.
- **Audit log** of every issued or denied token: who, which repo, why.
- **Agent container** (`agent-run`) that runs Claude Code with only the agent token.
- **Operations:** liveness and readiness probes, Prometheus metrics, signed image, Helm chart.

| Caller | Proves identity with | Endpoint |
|---|---|---|
| Developer (local agent) | user token of a permission-less **login app**, via device flow | `POST /token` |
| GitHub Actions workflow | the workflow's **OIDC token** | `POST /token/actions` (or `/token`) |

A token is issued only if the developer has write access to the repository, or the OIDC
token's `repository` and `sub` claims name it, and the agent app is installed there.

## Use it locally

Requirements: `curl`, `jq`, `gh`. You need the broker URL and the login app's client ID from
the deployment (pflege-de: [cc-gitops `docs/token-broker.md`](https://github.com/pflege-de/cc-gitops/blob/main/docs/token-broker.md)).

```sh
export TOKEN_BROKER_URL=https://<broker>   # internal route
export LOGIN_APP_CLIENT_ID=<client ID>
./agent-token my-org/my-repo              # prints a 1h agent token
```

The first run prints a code for <https://github.com/login/device>. The login token is cached
in `~/.cache/agent-token/login.json` (mode 600) for 8 hours, so later runs need no browser.

To run the agent with only that token, use the container setup in
[docs/local.md](docs/local.md): `agent-run` starts Claude Code with your checkout, renews the
token during long sessions and keeps your own keys and `gh` login out of the container.
Without a container, deny the agent read access to `~/.ssh`, `~/.config/gh` and
`~/.cache/agent-token`.

Commits made with local git are not signed. Merge agent PRs with **squash**, so the commit on
a branch that requires signatures is created and signed by GitHub.

## Use it in CI

Workflows request an OIDC token with audience `token-broker` and exchange it at the broker.
On GitHub-hosted runners that needs the public, Actions-only route; on self-hosted runners with
internal network access the internal route works too. Workflow template, runner selection and
optional ref/workflow restrictions: [docs/actions.md](docs/actions.md).

## Review rules

The agent app can approve PRs, and its approvals count toward required reviews. Every
repository it is installed on must therefore **require a code owner review** and have a
`CODEOWNERS` file naming human teams: bots cannot be code owners. See
[docs/github-apps.md](docs/github-apps.md).

## Deploy

Container image `ghcr.io/pflege-de/token-broker` and Helm chart `charts/token-broker`, published
to `oci://ghcr.io/pflege-de/charts`. Chart values are documented in
[`values.yaml`](charts/token-broker/values.yaml). The chart has no deployment-specific defaults;
pflege-de's deployment lives in [cc-gitops `apps/token-broker/`](https://github.com/pflege-de/cc-gitops/tree/main/apps/token-broker).

The broker needs outbound access to `api.github.com` and `token.actions.githubusercontent.com`
only; GitHub never calls it. Run it behind TLS.

| Variable | |
|---|---|
| `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY_FILE` | agent app |
| `GITHUB_ORG` | only repositories of this org get tokens |
| `LOGIN_APP_CLIENT_ID`, `LOGIN_APP_CLIENT_SECRET` | login app |
| `ACTIONS_OIDC_AUDIENCE` | default `token-broker` |
| `ACTIONS_OIDC_ISSUER` | default `https://token.actions.githubusercontent.com` |
| `ACTIONS_ALLOWED_REFS`, `ACTIONS_ALLOWED_WORKFLOWS` | optional allowlists, comma-separated globs |
| `LISTEN_ADDR`, `GITHUB_API_URL` | defaults `:8080`, `https://api.github.com` |

Endpoints besides `/token` and `/token/actions`: `/healthz` (liveness), `/readyz` (GitHub
accepts the app key), `/metrics` (Prometheus).

Setting up the two GitHub Apps: [docs/github-apps.md](docs/github-apps.md).

## Develop

```sh
go test ./...
golangci-lint run
scripts/check-chart-render.sh charts/token-broker   # chart render assertions
```

Releases: push a `vX.Y.Z` tag on `main` to build and sign the image. The chart is versioned
separately and published when `version` in `Chart.yaml` changes on `main`.
