---
title: Getting started
weight: 1
---

Pick how your agent runs. All paths need the broker URL from your deployment. If your
organization publishes it as the Actions variable `AGENT_TOKEN_BROKER_URL`, the Claude Code plugin
finds it itself.

{{< cards >}}
  {{< card
    link="claude-code/"
    title="Claude Code plugin"
    icon="play"
    subtitle="The main path: Claude Code on your host, acting as the agent app."
  >}}
  {{< card
    link="homebrew/"
    title="Homebrew"
    icon="download"
    subtitle="Install the client scripts with brew."
  >}}
  {{< card
    link="install-script/"
    title="Install script"
    icon="terminal"
    subtitle="Install a pinned release without a package manager."
  >}}
  {{< card
    link="container/"
    title="Container"
    icon="cube"
    subtitle="Run Claude Code in a container with only the agent token."
  >}}
  {{< card
    link="devcontainer/"
    title="Dev Container"
    icon="code"
    subtitle="Add the agent-token Dev Container Feature."
  >}}
  {{< card
    link="kubernetes/"
    title="Kubernetes"
    icon="server"
    subtitle="Deploy the broker with the Helm chart."
  >}}
{{< /cards >}}
