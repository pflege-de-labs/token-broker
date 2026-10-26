# 2. Token broker with device flow and Actions OIDC

- Status: accepted
- Date: 2026-10-23

## Context

Minting an installation token needs the agent app's private key. That key must not be copied
to laptops or into repository secrets. Developers and CI both need tokens, and each token must
be tied to someone allowed to work on the repository.

## Decision

A small service, the **token broker**, holds the key and issues single-repo tokens to two kinds
of callers:

- **Developers** authenticate with a user token of a second, permission-less **login app**
  (`pflege-de-agent-login`), obtained by device flow. The broker accepts only tokens of that
  app and requires the user to have write access to the repository.
- **GitHub Actions** workflows send their **OIDC token**. The broker verifies it against
  GitHub's keys and requires both the `repository` claim and `sub` to name the repository; for
  the immutable subject form the IDs must match the signed ID claims. Optional allowlists
  restrict `ref` and `job_workflow_ref`.

The broker also checks the app is installed on the repository and logs every decision.
Installation state is queried from GitHub per request instead of being tracked from webhooks.

## Alternatives

- **Developer's own `gh` token as proof (first draft):** carries broad scopes and is sent to
  the broker; replaced by the login app.
- **Company IdP (OIDC):** needs a mapping from IdP users to GitHub logins.
- **`actions/create-github-app-token` in workflows:** puts the private key into secrets.
- **Tracking installations via webhooks:** needs an inbound endpoint and state that can drift;
  GitHub is queried live anyway.

## Consequences

- One key, one rotation point; developers and workflows never see it.
- A cached login token can mint agent tokens for 8h, for any repository the developer can
  push to; it is treated as a credential.
- The device flow uses a public client ID, so the developer endpoint stays internal (ADR 3).
