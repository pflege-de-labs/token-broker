---
title: Agent-Commits signieren
weight: 3
---

`git commit` in einem Container erzeugt unsignierte Commits: GitHub signiert App-Commits nur, wenn
es sie selbst erstellt. Rulesets mit `required_signatures` blockieren sie dann auf geschützten
Branches. Squash-Merges funktionieren weiterhin, weil GitHub den Squash-Commit signiert.

`agent-commit` sendet die gestageten Änderungen an die GraphQL-Mutation `createCommitOnBranch` und
setzt den lokalen Branch auf den signierten Commit:

```sh
git add -A
agent-commit -m "feat: something" -m "Body."   # or -F <file>
```

* Es pusht beim Committen; ein separates `git push` gibt es nicht. Ein Branch, der auf origin
  fehlt, wird bei `HEAD` angelegt, und `HEAD` muss bereits auf GitHub liegen.
* Es verweigert, wenn der lokale Branch Commits hat, die origin fehlen, sowie bei neuen
  ausführbaren Dateien oder Moduswechseln: Die API kennt keinen Dateimodus, neue Dateien landen
  als `100644`. Committen Sie diese mit `git commit` und mergen Sie mit Squash.
* Es teilt große Änderungen auf. Übersteigen die Dateiinhalte `AGENT_COMMIT_MAX_BYTES` (Standard
  3 MB; GitHub hat einen Commit mit ~17 MB mit HTTP 499 beantwortet), sendet es mehrere Commits
  mit höchstens dieser Größe. Alle außer dem letzten erhalten `(part i/n)` am Ende der Betreffzeile,
  und erst der letzte enthält die ganze Änderung. Schlägt ein Teil fehl, bleiben die vorherigen auf
  origin und der lokale Branch steht auf ihnen: Führen Sie dasselbe `agent-commit` erneut aus, um
  den Rest zu senden.
* Es erzeugt keine Merge-Commits; führen Sie stattdessen einen Rebase auf den Basis-Branch durch.
* `AGENT_COMMIT_MODE=local` macht daraus ein einfaches `git commit`, für Repositories, die keine
  API-Commits wollen.

Im Dev Container weist `/etc/claude-code/CLAUDE.md` Claude Code an, `agent-commit` zu nutzen. Beim
Claude-Code-Plugin blockiert der Guard `git commit` und verweist Claude hierher.

Die vollständige Referenz steht unter [`agent-commit`](../../reference/client-cli/#agent-commit).
