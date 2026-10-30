---
title: Token Broker
layout: hextra-home
---

<!-- markdownlint-disable-next-line MD034 -->
{{< hextra/hero-badge link="https://github.com/pflege-de-labs/token-broker/releases" >}}
  Releases
{{< /hextra/hero-badge >}}

<div class="hx:mt-6 hx:mb-6">
{{< hextra/hero-headline >}}
  Coding agents with their own&nbsp;<br class="hx:sm:block hx:hidden" />GitHub identity
{{< /hextra/hero-headline >}}
</div>

<div class="hx:mb-12">
{{< hextra/hero-subtitle >}}
  Developers and GitHub Actions workflows exchange proof of who they are for a short-lived token
  of a dedicated agent GitHub App. Agent commits and pull requests show up as the app's bot and
  need a human review, and developer credentials never reach the agent.
{{< /hextra/hero-subtitle >}}
</div>

<div class="hx:mb-12">
{{< hextra/hero-button text="Get started" link="docs/getting-started" >}}
</div>

<div class="content">

## Features

{{< cards >}}
  {{< card
    title="Narrow tokens"
    icon="key"
    subtitle="One repository, one hour, contents, pull request and issue access only."
  >}}
  {{< card
    title="Developer login"
    icon="user"
    subtitle="Device flow with a permission-less login app, for repositories you can write to."
  >}}
  {{< card
    title="GitHub Actions"
    icon="play"
    subtitle="OIDC exchange at POST /token/actions, safe to expose, with optional allowlists."
  >}}
  {{< card
    title="Private key stays put"
    icon="shield-check"
    subtitle="The app's private key lives in the broker; agents and workstations never see it."
  >}}
  {{< card
    title="Audit log"
    icon="document-text"
    subtitle="Every issued or denied token is logged: who, which repository, why."
  >}}
  {{< card
    title="Agent container"
    icon="cube"
    subtitle="agent-run starts Claude Code with only the agent token."
  >}}
  {{< card
    title="Operations"
    icon="server"
    subtitle="Liveness and readiness probes, Prometheus metrics, a signed image and a Helm chart."
  >}}
{{< /cards >}}

## Who calls the broker

| Caller | Proves identity with | Endpoint |
| --- | --- | --- |
| Developer (local agent) | user token of a permission-less login app, via device flow | `POST /token` |
| GitHub Actions workflow | the workflow's OIDC token | `POST /token/actions` (or `/token`) |

A token is issued only if the developer has write access to the repository, or the OIDC token's
`repository` and `sub` claims name it, and the agent app is installed there.

</div>
