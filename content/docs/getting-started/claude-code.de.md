---
title: Claude-Code-Plugin
weight: 1
---

Installieren Sie das Plugin `agent-token`, damit Claude Code auf Ihrem Rechner als Agent-App
committet und GitHub aufruft statt als Sie.

## Bevor Sie beginnen {#before-you-start}

* `jq`, `gh` (angemeldet), `curl` und `git` auf dem Rechner.
* Die Agent-App ist auf Ihrem Repository installiert, und das Repository trägt das Topic
  `agent-token-broker`.
* Die URL des Brokers. Das Plugin sucht sie in dieser Reihenfolge: die Umgebungsvariable
  `TOKEN_BROKER_URL`, die Plugin-Option `broker_url`, die Actions-Variable
  `AGENT_TOKEN_BROKER_URL` der Organisation des Repositorys, gelesen mit Ihrem `gh`.
  Repository-Variablen werden ignoriert, damit Repository-Admins Ihre Anmeldung nicht an einen
  anderen Server umleiten können. Nur `https://`-URLs werden akzeptiert.

## Installieren {#install}

```sh
claude plugin marketplace add pflege-de-labs/token-broker
claude plugin install agent-token@pflege-de-token-broker
```

Um die Broker-URL bei der Installation zu setzen, ergänzen Sie `--config broker_url=https://<broker>`.
Sie können sie auch später in Claude Code mit `/config` setzen.

Das Plugin bringt die Client-Skripte mit: Sein Verzeichnis `bin/` liegt im PATH des Bash-Tools von
Claude. Ihr eigener `PATH` hat Vorrang, eine Installation per Homebrew oder Skript gewinnt also.
Das Plugin folgt `main`, während Homebrew, das Installationsskript und die Container ein
festgelegtes Release installieren. Auto-Update für Marketplaces ist standardmäßig aus;
aktualisieren Sie mit `claude plugin update agent-token@pflege-de-token-broker`.

## Anmelden {#log-in}

Einmal alle 8 Stunden, im Claude-Code-Prompt:

```text
! agent-token --login
```

Beim ersten Login erscheint ein Code für <https://github.com/login/device>. Das Login-Token liegt
in `~/.cache/agent-token/login.json`.

## Was in einer Sitzung passiert {#what-happens-in-a-session}

Ein `SessionStart`-Hook prüft, ob das Repository das Topic `agent-token-broker` trägt. Wenn ja,
wird Claude angewiesen, mit Agent-Tokens zu committen und GitHub aufzurufen, und der Hook ergänzt
das Ergebnis von `agent-token --check`. In allen anderen Verzeichnissen bleibt das Plugin still.

In einer solchen Sitzung blockiert ein `PreToolUse`-Hook Bash-Befehle mit `git commit` oder
`git push` sowie `gh`, auch mit vollem Pfad aufgerufen. Claude nutzt stattdessen
[`agent-commit`](../../guides/signed-commits/) und `agent-gh`.

`gh` in einem einzelnen, alleinstehenden `podman exec`, `docker exec` oder `devcontainer exec` ist
erlaubt, denn im [Dev Container](../devcontainer/) ist `gh` der Wrapper mit dem eigenen Login des
Containers. Der Befehl für den Container steht in einfachen Anführungszeichen, zum Beispiel
`podman exec -u vscode <container> bash -lc 'gh pr create --fill'`. Befehle, die um das exec
herum verkettet sind, `GH_TOKEN`, `GITHUB_TOKEN`, `--env-file` und `gh` mit Pfad bleiben blockiert.

Vor einem Commit, einem Push oder `agent-gh pr create` prüft der Hook außerdem Ihren Login. Fehlt
er oder läuft er in weniger als 5 Minuten ab, wird der Befehl blockiert, und Claude bittet Sie,
`! agent-token --login` auszuführen, statt auf anderem Weg zu committen oder zu pushen.

Ist Ihr `gh` der `agent-gh`-Wrapper und Ihr Login abgelaufen, kann das Plugin auch das Topic
nicht lesen. Claude wird dann angewiesen, Sie um einen Login zu bitten, und der Hook blockiert
`git commit`, `git push` und `gh`, bis Sie sich angemeldet haben.

Die Prüfung läuft auch später: Vor einem `git commit`, `git push` oder `gh`-Befehl in einer
ungeschützten Sitzung prüft der Guard das Repository, auf das der Befehl zielt. Eine Sitzung, die vor
der Installation der App oder in einem übergeordneten Verzeichnis gestartet wurde, ist ab diesem
Befehl geschützt.

{{< callout type="warning" >}}
Das Plugin ist eine Leitplanke, keine Sandbox. Der Hook vergleicht Befehlstext, daher kommen
`g=git; $g push` oder ein Skript, das pusht, mit Ihren Zugangsdaten durch. Er prüft auch nicht, auf
welchen Container ein exec zielt: Einer, dessen `gh` Ihren Login hat, kommt durch.
GitHub-MCP-Tools werden nicht geprüft. Für Isolation nutzen Sie
den [Container](../container/) oder den [Dev Container](../devcontainer/). Siehe das
[Sicherheitsmodell](../../concepts/security-model/).
{{< /callout >}}

## Nächste Schritte {#next-steps}

* [Agent-Commits signieren](../../guides/signed-commits/)
* [Client-Befehle](../../reference/client-cli/)
