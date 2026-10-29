---
title: Homebrew
weight: 2
---

Installieren Sie die Client-Skripte unter macOS oder Linux mit Homebrew. Die Formel hängt von `jq`
und `gh` ab.

```sh
brew tap pflege-de-labs/token-broker https://github.com/pflege-de-labs/token-broker
brew install agent-token
```

Setzen Sie die Broker-URL und fordern Sie ein Token an:

```sh
export TOKEN_BROKER_URL=https://<broker>
agent-token my-org/my-repo    # prints a 1h agent token
```

Beim ersten Aufruf erscheint ein Code für <https://github.com/login/device>. Das Login-Token wird 8
Stunden in `~/.cache/agent-token/login.json` (Modus 600) zwischengespeichert, spätere Aufrufe
brauchen keinen Browser.

Homebrew installiert ein festgelegtes Release. Wenn Sie die Skripte aus Claude Code nutzen wollen,
ohne die Installation selbst zu pflegen, verwenden Sie das [Plugin](../claude-code/).

{{< callout type="info" >}}
Ohne Container verweigern Sie dem Agenten den Lesezugriff auf `~/.ssh`, `~/.config/gh` und
`~/.cache/agent-token`.
{{< /callout >}}

Was jedes Skript tut, steht unter [Client-Befehle](../../reference/client-cli/).
