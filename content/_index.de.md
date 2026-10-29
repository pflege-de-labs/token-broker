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
  Coding-Agenten mit eigener&nbsp;<br class="hx:sm:block hx:hidden" />GitHub-Identität
{{< /hextra/hero-headline >}}
</div>

<div class="hx:mb-12">
{{< hextra/hero-subtitle >}}
  Entwickler und GitHub-Actions-Workflows tauschen einen Identitätsnachweis gegen ein kurzlebiges
  Token einer eigenen Agent-GitHub-App. Commits und Pull Requests des Agenten erscheinen als Bot
  der App und brauchen ein menschliches Review, und die Zugangsdaten der Entwickler erreichen den
  Agenten nie.
{{< /hextra/hero-subtitle >}}
</div>

<div class="hx:mb-12">
{{< hextra/hero-button text="Loslegen" link="docs/getting-started" >}}
</div>

## Funktionen {#features}

{{< cards >}}
  {{< card
    title="Enge Tokens"
    icon="key"
    subtitle="Ein Repository, eine Stunde, nur Zugriff auf Inhalte, Pull Requests und Issues."
  >}}
  {{< card
    title="Entwickler-Login"
    icon="user"
    subtitle="Device Flow mit Login-App ohne Berechtigungen, für Repositories mit Schreibzugriff."
  >}}
  {{< card
    title="GitHub Actions"
    icon="play"
    subtitle="OIDC-Austausch über POST /token/actions, öffentlich nutzbar, mit optionalen Positivlisten."
  >}}
  {{< card
    title="Privater Schlüssel bleibt im Broker"
    icon="shield-check"
    subtitle="Der private Schlüssel der App liegt im Broker; Agenten und Arbeitsplätze sehen ihn nie."
  >}}
  {{< card
    title="Audit-Log"
    icon="document-text"
    subtitle="Jedes ausgestellte oder abgelehnte Token wird protokolliert: wer, was, warum."
  >}}
  {{< card
    title="Agent-Container"
    icon="cube"
    subtitle="agent-run startet Claude Code nur mit dem Agent-Token."
  >}}
  {{< card
    title="Betrieb"
    icon="server"
    subtitle="Liveness-/Readiness-Probes, Prometheus-Metriken, signiertes Image, Helm-Chart."
  >}}
{{< /cards >}}

## Wer den Broker aufruft {#who-calls-the-broker}

| Aufrufer | Identitätsnachweis | Endpunkt |
| --- | --- | --- |
| Entwickler (lokaler Agent) | User-Token einer Login-App ohne Berechtigungen, per Device Flow | `POST /token` |
| GitHub-Actions-Workflow | das OIDC-Token des Workflows | `POST /token/actions` (oder `/token`) |

Ein Token wird nur ausgestellt, wenn der Entwickler Schreibzugriff auf das Repository hat oder die
Claims `repository` und `sub` des OIDC-Tokens es nennen, und die Agent-App dort installiert ist.
