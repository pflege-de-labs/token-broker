---
title: GitHub-Apps einrichten
weight: 1
---

Der Broker braucht zwei GitHub-Apps im Besitz der Organisation. Die Einstellungen finden Sie unter
**Organization settings → Developer settings → GitHub Apps**.

| | Agent-App | Login-App |
| --- | --- | --- |
| Zweck | Identität, als die Agenten committen, pushen und Pull Requests öffnen | Weist nach, wer ein Entwickler ist (Device Flow) |
| Repository-Berechtigungen | Contents RW, Pull requests RW, Issues RW, Metadata R | keine |
| Berechtigungen für Organisation / Konto | keine | keine |
| Device Flow | aus | an |
| Installiert | auf ausgewählten Repositories | nicht nötig |
| Broker-Konfiguration | `GITHUB_APP_ID`, privater Schlüssel | `LOGIN_APP_CLIENT_ID`, Client-Secret |

## Agent-App {#agent-app}

* Besitzer ist die Organisation, kein persönliches Konto. **Where can this app be installed:**
  nur auf diesem Konto.
* **Webhook:** Active nicht angehakt. Der Broker empfängt keine Ereignisse.
* **Identifying and authorizing users:** keine Callback-URL, **Request user authorization (OAuth)
  during installation** aus, **Enable Device Flow** aus. User-Tokens dieser App würden als der
  Entwickler handeln.
* **Repository permissions:** Contents, Pull requests und Issues **Read and write**, Metadata
  **Read-only**. Alles andere **No access**, insbesondere:
  * Workflows, damit ein Agent die CI nicht ändern kann, um seine Rechte auszuweiten.
  * Administration, Secrets, Environments und Actions, damit er weder Repositories noch Secrets
    verwalten kann.
  * Checks und Statuses, damit er einen erforderlichen Check nicht als grün melden kann.
* **Organization** und **Account permissions:** überall **No access**. **Subscribe to events:**
  keine.
* **Private keys:** Erzeugen Sie einen Schlüssel. Er gehört nur ins Broker-Secret als
  `private-key.pem`, nie in ein Repository-Secret und nie auf einen Laptop. Löschen Sie die
  heruntergeladene Datei danach.
* **Install App** auf **Only select repositories**: die Repositories, an denen Agenten arbeiten
  dürfen.
* Die App ist in keinem Ruleset ein **Bypass-Actor**.
* Notieren Sie die **App ID** (`config.appId`).

Jedes Repository, auf dem die App installiert ist, braucht außerdem
[Review-Regeln](../review-rules/).

Der Broker fordert pro Token nur die vier Berechtigungen an, deshalb erweitert eine größere
Berechtigung der App nichts für Agenten. `AGENT_PERMISSIONS` (Chart: `config.agentPermissions`)
ändert diese Menge; jede Installation muss jede darin enthaltene Berechtigung akzeptiert haben,
sonst verweigert GitHub das Token. Halten Sie die App minimal: Der private Schlüssel allein kann
Tokens mit allem ausstellen, was die App hat.

## Login-App {#login-app}

* Besitzer ist die Organisation; Installation nur auf diesem Konto.
* **Webhook:** Active nicht angehakt.
* **Repository**, **Organization** und **Account permissions:** überall **No access**.
* **Enable Device Flow** an. **Expire user authorization tokens** an: Login-Tokens leben 8
  Stunden.
* Callback-URL: für den Device Flow nicht nötig. Besteht das Formular darauf, nehmen Sie die
  Broker-URL.
* **Request user authorization (OAuth) during installation** aus; die App muss nicht installiert
  sein.
* Notieren Sie die **Client ID** (`config.loginClientId`). Der Broker liefert sie unter
  `/login-app` an Clients aus.
* Erzeugen Sie ein Client-Secret. Es gehört nur ins Broker-Secret als `login-client-secret`.

## Broker-Secret und Values {#broker-secret-and-values}

```sh
kubectl create secret generic token-broker-credentials \
  --from-file=private-key.pem=<agent-app>.private-key.pem \
  --from-literal=login-client-secret="$LOGIN_CLIENT_SECRET"
```

```yaml
existingSecret: token-broker-credentials
config:
  appId: "<agent app ID>"
  org: my-org
  loginClientId: "<login app client ID>"
```

Nutzen Sie bevorzugt einen externen Secret-Manager statt das Secret von Hand anzulegen.

## Commit-Identität des Agenten {#commit-identity-of-the-agent}

Die Commit-E-Mail des Bots verwendet die Bot-User-ID, nicht die App-ID:

```sh
id=$(gh api "/users/<app-slug>%5Bbot%5D" --jq .id)
echo "<app-slug>[bot] <${id}+<app-slug>[bot]@users.noreply.github.com>"
```

Commits, die per API mit einem Installation-Token erzeugt werden, signiert GitHub und ordnet sie
automatisch dieser Identität zu.

## Zugangsdaten rotieren {#rotate-credentials}

* Privater Schlüssel der Agent-App: neuen Schlüssel erzeugen, Secret aktualisieren, Broker neu
  ausrollen (die Checksum-Annotation des Charts deckt nur ein vom Chart verwaltetes Secret ab),
  dann den alten Schlüssel löschen.
* Client-Secret der Login-App: gleiche Reihenfolge. Login-Tokens der Entwickler bleiben gültig;
  sie werden gegen die App geprüft, nicht gegen das Secret.
