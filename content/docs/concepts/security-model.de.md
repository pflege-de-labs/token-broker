---
title: Sicherheitsmodell
weight: 2
---

## Was der Agent nie sieht {#what-the-agent-never-sees}

* Den privaten Schlüssel der Agent-App und das Client-Secret der Login-App. Sie existieren nur im
  Broker.
* Die eigenen Zugangsdaten des Entwicklers. Commits und API-Aufrufe des Agenten nutzen
  Agent-Tokens, sie können also nicht als der Entwickler handeln.

Ein Agent-Token ist auf ein Repository beschränkt, lebt eine Stunde und trägt nur die
konfigurierten Berechtigungen. Abgesehen von Metadata sind das standardmäßig Contents, Pull
requests und Issues. Es hat keine Berechtigungen für Workflows, Administration, Secrets oder
Statuses, kann also weder die CI ändern noch das Repository verwalten noch einen erforderlichen
Check als grün melden.

## Menschen bleiben beteiligt {#humans-stay-in-the-loop}

Die Agent-App kann Pull Requests freigeben, und mit Schreibrechten auf Inhalte würden ihre
Freigaben auf erforderliche Reviews angerechnet. Jedes Repository, auf dem sie installiert ist,
muss deshalb ein Code-Owner-Review verlangen und eine `CODEOWNERS`-Datei haben, die menschliche
Teams nennt: Bots können keine Code Owner sein. Siehe
[Review-Regeln setzen](../../guides/review-rules/).

## Das Plugin ist eine Leitplanke, keine Sandbox {#the-plugin-is-a-guardrail-not-a-sandbox}

Das Claude-Code-Plugin weist Claude an, Agent-Tokens zu nutzen, und blockiert `git commit`,
`git push` und ein bloßes `gh`, indem es Befehlstext vergleicht. Ein Befehl wie `env git push`,
`/usr/bin/git push` oder ein Skript, das pusht, kommt durch und nutzt die Zugangsdaten des
Entwicklers. Die Sperre folgt außerdem der Sitzung, nicht dem Verzeichnis: Nach einem `cd` in ein
anderes Repository gilt sie weiter, und eine Sitzung, die außerhalb eines agent-token-Repositorys
gestartet wurde, bleibt ungeschützt.

Repository-Admins können Topics von Hand ändern. Ein falsches Topic kostet einen fehlgeschlagenen
Aufruf und sonst nichts, weil der Broker Tokens dort ablehnt, wo die App nicht installiert ist.

## Rechner versus Container {#host-versus-container}

| | Rechner mit Plugin | Container oder Dev Container |
| --- | --- | --- |
| Zugangsdaten des Entwicklers (`~/.ssh`, `gh`-Login) | für den Agenten erreichbar | nicht eingebunden |
| Durchsetzung | Guard auf Befehlstext | der Inhalt des Containers |
| Netzwerk | unbeschränkt | Dev Container: Egress-Firewall mit Positivliste |

Auf dem Rechner verweigern Sie dem Agenten den Lesezugriff auf `~/.ssh`, `~/.config/gh` und
`~/.cache/agent-token`. Für Isolation betreiben Sie den Agenten mit
[`agent-run`](../../getting-started/container/) oder im
[Dev Container](../../getting-started/devcontainer/). Die Firewall des Dev Containers kann der
Agent nicht aufheben, aber Ihr weitergeleiteter SSH-Agent kann noch signieren; für volle Isolation
nutzen Sie `agent-run`. Die Rückfragen von Claude zu überspringen ist nur mit aktiver Firewall
vertretbar.

## Erreichbarkeit des Brokers {#exposure-of-the-broker}

Die Client-ID des Device Flows ist öffentlich, ein erreichbarer Broker lädt daher zu Phishing ein.
Halten Sie `/token` intern. Nur `/token/actions` ist für die öffentliche Erreichbarkeit gebaut: Es
akzeptiert Actions-OIDC-Tokens und sonst nichts. GitHub ruft den Broker nie auf; er braucht
ausgehenden Zugriff nur auf `api.github.com` und `token.actions.githubusercontent.com`. Betreiben
Sie ihn hinter TLS.

Grenzen: Commits mit lokalem git sind unsigniert, nutzen Sie daher auf Branches, die Signaturen
verlangen, [`agent-commit`](../../guides/signed-commits/) oder Squash-Merge.
