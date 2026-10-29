---
title: Documentation
---

Token Broker gives coding agents such as Claude Code their own GitHub identity. A developer or a
GitHub Actions workflow proves who they are, and the broker hands back a one-hour token of the
agent GitHub App for a single repository. The app's private key never leaves the broker.

{{< cards >}}
  {{< card
    link="getting-started/"
    title="Getting started"
    icon="play"
    subtitle="Install the client and get your first agent token, or deploy the broker."
  >}}
  {{< card
    link="guides/"
    title="Guides"
    icon="book-open"
    subtitle="Set up the GitHub Apps, use tokens in Actions, sign commits, set review rules."
  >}}
  {{< card
    link="reference/"
    title="Reference"
    icon="document-text"
    subtitle="Client commands and variables, broker configuration, endpoints, Helm values, metrics."
  >}}
  {{< card
    link="concepts/"
    title="Concepts"
    icon="light-bulb"
    subtitle="The two auth paths and the security model."
  >}}
{{< /cards >}}

The README, the longer docs and the architecture decision records stay in the repository:
[`docs/`](https://github.com/pflege-de-labs/token-broker/tree/main/docs) and the
[ADRs](https://github.com/pflege-de-labs/token-broker/tree/main/docs/adr).
