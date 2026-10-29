---
title: Dokumentation
---

Token Broker gibt Coding-Agenten wie Claude Code eine eigene GitHub-Identität. Ein Entwickler oder
ein GitHub-Actions-Workflow weist sich aus, und der Broker liefert ein einstündiges Token der
Agent-GitHub-App für genau ein Repository. Der private Schlüssel der App verlässt den Broker nie.

{{< cards >}}
  {{< card
    link="getting-started/"
    title="Erste Schritte"
    icon="play"
    subtitle="Den Client installieren und das erste Agent-Token holen, oder den Broker deployen."
  >}}
  {{< card
    link="guides/"
    title="Anleitungen"
    icon="book-open"
    subtitle="GitHub-Apps einrichten, Tokens in Actions nutzen, Commits signieren, Review-Regeln setzen."
  >}}
  {{< card
    link="reference/"
    title="Referenz"
    icon="document-text"
    subtitle="Client-Befehle und -Variablen, Broker-Konfiguration, Endpunkte, Helm-Values, Metriken."
  >}}
  {{< card
    link="concepts/"
    title="Konzepte"
    icon="light-bulb"
    subtitle="Die zwei Authentifizierungswege und das Sicherheitsmodell."
  >}}
{{< /cards >}}

README, die ausführlicheren Dokumente und die Architekturentscheidungen (ADRs) bleiben im
Repository, auf Englisch:
[`docs/`](https://github.com/pflege-de-labs/token-broker/tree/main/docs) und
[ADRs](https://github.com/pflege-de-labs/token-broker/tree/main/docs/adr).
