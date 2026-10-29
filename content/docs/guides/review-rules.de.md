---
title: Review-Regeln setzen
weight: 4
---

Die Agent-App hat Schreibrechte auf Inhalte, daher würden ihre Freigaben auf erforderliche Reviews
angerechnet. Bots können keine Code Owner sein, ein Code-Owner-Review schließt die Lücke. Jedes
Repository, auf dem die App installiert ist, braucht deshalb:

1. Eine `CODEOWNERS`-Datei, die menschliche Teams nennt.
2. Eine Regel auf dem Default-Branch, die ein **Code-Owner-Review** verlangt.
3. Keinen Bypass für die Agent-App in irgendeinem Ruleset.

Commits und Pull Requests des Agenten erscheinen dann als Bot der App und brauchen ein
menschliches Review.

Wenn Sie signierte Commits verlangen, mergen Sie Agent-Pull-Requests mit **Squash**, damit der
Commit auf dem geschützten Branch von GitHub erstellt und signiert wird. Siehe
[Agent-Commits signieren](../signed-commits/).

Siehe auch [GitHub-Apps einrichten](../github-apps/).
