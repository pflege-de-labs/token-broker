---
title: Architektur
weight: 1
---

Coding-Agenten müssen Code pushen und Pull Requests öffnen. Geben Sie ihnen die Zugangsdaten eines
Entwicklers, sieht jede Aktion des Agenten nach dem Entwickler aus, und eine Prompt Injection hält
dann alles, was der Entwickler darf. Token Broker gibt dem Agenten stattdessen eine eigene
GitHub-Identität: eine GitHub-App. Ihre Commits und Pull Requests erscheinen als `<app>[bot]` und
brauchen ein menschliches Review.

## Ein Schlüssel, ein Ort {#one-key-one-place}

Eine App kann Installation-Tokens nur mit ihrem privaten Schlüssel ausstellen. Der Schlüssel liegt
allein im Broker. Agenten, Container und Arbeitsplätze bitten den Broker um ein Token und sehen den
Schlüssel nie.

## Zwei Authentifizierungswege {#two-auth-paths}

| Aufrufer | Identitätsnachweis | Endpunkt |
| --- | --- | --- |
| Entwickler (lokaler Agent) | User-Token einer Login-App ohne Berechtigungen, per Device Flow | `POST /token` |
| GitHub-Actions-Workflow | das OIDC-Token des Workflows | `POST /token/actions` (oder `/token`) |

* **Entwickler.** `agent-token --login` führt den Device Flow von GitHub mit der **Login-App** aus,
  einer App ganz ohne Berechtigungen. Sie weist nur nach, wer der Entwickler ist. Das Login-Token
  liegt 8 Stunden im Cache des Entwicklers. Der Broker fragt GitHub, ob dieser Benutzer
  Schreibzugriff auf das angeforderte Repository hat, und lehnt sonst ab: Ein Entwickler kann dem
  Agenten nur Repositories übergeben, auf die er selbst pushen könnte.
* **Workflow.** Der Workflow fordert ein OIDC-Token mit der vom Broker erwarteten Audience an und
  sendet es an den Broker. Der Broker prüft es gegen den Aussteller von GitHub. Ein Workflow
  bekommt ein Token nur für das Repository, in dem er läuft, optional beschränkt auf bestimmte Refs
  und Workflows. `/token/actions` akzeptiert nur diese Tokens, deshalb kann eine öffentliche Route
  ihn weiterleiten, während alles andere intern bleibt.

## Was das Token ist {#what-the-token-is}

In beiden Fällen geht der Broker dann so vor:

1. Er prüft, dass das Repository zu einer der konfigurierten Organisationen gehört.
2. Er signiert ein App-JWT mit dem privaten Schlüssel und sucht die Installation der App auf dem
   Repository; ist die App dort nicht installiert, lehnt er ab.
3. Er stellt ein Installation-Token für genau dieses Repository aus, mit den konfigurierten
   Berechtigungen (Standard: Contents, Pull requests und Issues schreiben, Metadata lesen).

Das Token lebt eine Stunde. Clients holen Tokens bei Bedarf, je Repository, in dem Moment, in dem
git, `gh` oder der GitHub-MCP-Server eines brauchen, und halten sie im Cache. Jedes ausgestellte
oder abgelehnte Token wird protokolliert: wer, welches Repository, warum.

## Bestandteile {#parts}

* **Broker:** ein kleiner zustandsloser Go-Dienst, betrieben als Helm-Chart mit zwei Replikaten. Er
  hat keine Datenbank und ruft nie die Kubernetes-API auf.
* **Client-Skripte:** `agent-token` und die darauf aufbauenden Helfer. Siehe
  [Client-Befehle](../../reference/client-cli/).
* **Claude-Code-Plugin, Dev Container Feature und `agent-run`:** drei Wege, den Client in die
  Umgebung des Agenten zu bringen. Siehe [Erste Schritte](../../getting-started/).

Einrichtung: [GitHub-Apps einrichten](../../guides/github-apps/). Endpunkte und Fehler:
[Endpunkte](../../reference/endpoints/).
