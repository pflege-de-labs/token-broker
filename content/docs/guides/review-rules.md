---
title: Set review rules
weight: 4
---

The agent app has contents write permission, so its approvals would count toward required
reviews. Bots cannot be code owners, so a code owner review closes the gap. Every repository the
app is installed on therefore needs:

1. A `CODEOWNERS` file that names human teams.
2. A rule on the default branch that requires a **code owner review**.
3. No bypass for the agent app in any ruleset.

Agent commits and pull requests then show up as the app's bot and need a human review.

If you require signed commits, merge agent pull requests with **squash**, so the commit on the
protected branch is created and signed by GitHub. See [Sign agent commits](../signed-commits/).

See also [Set up the GitHub Apps](../github-apps/).
