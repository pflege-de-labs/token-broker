---
title: Erste Schritte
weight: 1
---

Wählen Sie, wie Ihr Agent läuft. Alle Wege brauchen die Broker-URL aus Ihrem Deployment. Wenn Ihre
Organisation sie als Actions-Variable `AGENT_TOKEN_BROKER_URL` veröffentlicht, findet das
Claude-Code-Plugin sie selbst.

{{< cards >}}
  {{< card
    link="claude-code/"
    title="Claude-Code-Plugin"
    icon="play"
    subtitle="Der Hauptweg: Claude Code auf Ihrem Rechner, als Agent-App."
  >}}
  {{< card
    link="homebrew/"
    title="Homebrew"
    icon="download"
    subtitle="Die Client-Skripte mit brew installieren."
  >}}
  {{< card
    link="install-script/"
    title="Installationsskript"
    icon="terminal"
    subtitle="Ein festgelegtes Release ohne Paketmanager installieren."
  >}}
  {{< card
    link="container/"
    title="Container"
    icon="cube"
    subtitle="Claude Code in einem Container nur mit dem Agent-Token betreiben."
  >}}
  {{< card
    link="devcontainer/"
    title="Dev Container"
    icon="code"
    subtitle="Das Dev Container Feature agent-token hinzufügen."
  >}}
  {{< card
    link="kubernetes/"
    title="Kubernetes"
    icon="server"
    subtitle="Den Broker mit dem Helm-Chart deployen."
  >}}
{{< /cards >}}
