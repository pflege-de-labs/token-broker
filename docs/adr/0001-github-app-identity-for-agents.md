# 1. GitHub App as the identity of coding agents

- Status: accepted
- Date: 2026-10-23

## Context

Coding agents committed, pushed and opened PRs with the credentials of the developer running
them. Reviews could not tell agent work from human work, agents had every permission the
developer had, and a leaked agent environment leaked a developer's keys. Several developers use
agents, so the identity must be shared without sharing a secret, and every token must still be
attributable to the developer or workflow that requested it.

## Decision

Agents act as an org-owned **GitHub App** (`pflege-de-agent`) with repository permissions
contents, pull requests and issues (write) and metadata (read) only, no webhooks, installed on
selected repositories. Agents receive 1h installation tokens limited to one repository. The
app's private key is held by the token broker only (ADR 2).

## Alternatives

- **Shared machine user:** one long-lived PAT or SSH key for everybody, one rotation for
  everybody on a leak, no attribution, costs a seat.
- **One machine user per developer:** attribution, but long-lived credentials and a seat each.
- **Developer credentials (status quo):** no separation of permissions, no reviewable boundary.

## Consequences

- Agent work appears as `pflege-de-agent[bot]`; developers can review and approve it.
- The app cannot sign commits with a key: commits made with local git are unsigned, so agent
  PRs are squash-merged (GitHub signs the result).
- The app's approvals count toward required reviews; ADR 4 handles that.
