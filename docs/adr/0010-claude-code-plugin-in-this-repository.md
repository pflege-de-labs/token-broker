# 10. Claude Code plugin in this repository

- Status: accepted
- Date: 2026-10-28

## Context

Claude Code on a host should notice when a repository uses agent tokens and switch to the client
scripts. The signal is the topic `agent-token-broker`, which github-ops sets with `agent: true`;
the agent app installation itself is not readable with a user token. The hook needs a home that
developers can install as a Claude Code plugin.

## Decision

The plugin `agent-token` and its marketplace `pflege-de-token-broker` live in this repository
(`plugins/`, `.claude-plugin/`), as `pflege-de/mcp` ships its plugin. Its text describes the
client scripts and the broker's rules, which change here.

## Alternatives

- **Org-wide plugin repository:** one marketplace for all plugins; worth it from about three
  plugins. Its entries can point at this repository, so moving later costs nothing.
- **devcontainer-features:** public and next to the scripts (ADR 7), but the plugin carries no
  value for public users, and its rules follow the broker.

## Consequences

- Developers add one marketplace per plugin repository until an org-wide one exists.
- The repository is private: installing uses the developer's git login, background updates may
  need `GITHUB_TOKEN`.
