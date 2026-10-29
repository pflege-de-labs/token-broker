---
title: Security model
weight: 2
---

## What the agent never sees

* The agent app's private key and the login app's client secret. They exist only in the broker.
* The developer's own credentials. Agent commits and API calls use agent tokens, so they cannot
  act as the developer.

An agent token is limited to one repository, lives one hour and carries only the configured
permissions. Metadata aside, the default is contents, pull requests and issues. It has no
workflow, administration, secrets or status permissions, so it cannot edit CI, manage the
repository or report a required check as green.

## Humans stay in the loop

The agent app can approve pull requests, and with contents write its approvals would count toward
required reviews. Every repository it is installed on must therefore require a code owner review
and have a `CODEOWNERS` file that names human teams: bots cannot be code owners. See
[Set review rules](../../guides/review-rules/).

## The plugin is a guardrail, not a sandbox

The Claude Code plugin tells Claude to use agent tokens and blocks `git commit`, `git push` and a
bare `gh` by matching command text. A command like `env git push`, `/usr/bin/git push` or a
script that pushes gets through and uses the developer's credentials. The block also follows the
session, not the directory: after a `cd` into another repository it still applies, and a session
started outside an agent-token repository stays unguarded.

Repository admins can edit topics by hand. A wrong topic costs a failed call and nothing more,
because the broker refuses tokens where the app is not installed.

## Host versus container

| | Host with the plugin | Container or Dev Container |
| --- | --- | --- |
| Developer credentials (`~/.ssh`, `gh` login) | reachable by the agent | not mounted |
| Enforcement | command-text guard | the container's contents |
| Network | unrestricted | Dev Container: egress firewall with an allowlist |

On the host, deny the agent read access to `~/.ssh`, `~/.config/gh` and `~/.cache/agent-token`.
For isolation run the agent with [`agent-run`](../../getting-started/container/) or in the
[Dev Container](../../getting-started/devcontainer/). The Dev Container's firewall cannot be
lifted by the agent, but your forwarded SSH agent can still sign; use `agent-run` for full
isolation. Skipping Claude's permission prompts is reasonable only with the firewall active.

## Exposure of the broker

The device-flow client ID is public, so a reachable broker invites phishing. Keep `/token`
internal. Only `/token/actions` is built for public exposure: it accepts Actions OIDC tokens and
nothing else. GitHub never calls the broker; it needs outbound access to `api.github.com` and
`token.actions.githubusercontent.com` only. Run it behind TLS.

Limits: commits made with local git are unsigned, so on branches that require signatures use
[`agent-commit`](../../guides/signed-commits/) or squash-merge.
