# 4. Agent approvals do not count toward required reviews

- Status: accepted
- Date: 2026-10-23

## Context

With contents write access, the agent app's PR approvals count toward required approvals. A
developer could open a PR and let their own agent approve it, which defeats review. GitHub has
no setting that excludes a single app from counting. Renovate PRs are the exception: there an
agent review and approval should be enough.

## Decision

Bots cannot be code owners. Every repository with the agent app gets a separate ruleset,
`agent-review`, that requires a **code owner review**, and a `CODEOWNERS` file naming human
teams. The Renovate app is a bypass actor in `pull_request` mode, so when Renovate merges its own
PR the ruleset does not apply and the agent's approval satisfies the regular review rule.

In pflege-de this is driven by `agent` in github-ops `repositories.yaml`, which also sets the
app's installation repositories authoritatively and fails the plan if `CODEOWNERS` is missing.

## Alternatives

- **Code owner review in the shared default-branch ruleset:** lost when a repository opts out
  of that ruleset.
- **Exception by head branch (`renovate/*`):** rulesets only match the target branch, and any
  writer can name a branch `renovate/…`; the bypass is tied to the Renovate app's identity.
- **Custom required status check counting human approvals:** more moving parts for the same
  result.

## Consequences

- An agent approval never merges a human-merged PR on its own.
- Renovate PRs merged by Renovate need only the agent's approval; in repositories that opted out
  of the default ruleset Renovate can merge without any approval.
- Every new agent repository needs a `CODEOWNERS` file before the app can be enabled.
