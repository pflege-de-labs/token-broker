#!/usr/bin/env bash
# PreToolUse(Bash): in sessions session-start.sh marked, blocks commits, pushes and gh calls with the user's credentials.
# shortcut: matches the command text, so `env git push` or `/usr/bin/git push` slip through; agent-run is the sandbox.
set -euo pipefail
input=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$input")
[[ $sid =~ ^[A-Za-z0-9-]+$ && -f ${TMPDIR:-/tmp}/claude-agent-token/$sid ]] || exit 0
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")

if grep -Eq '(^|[^[:alnum:]_-])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(commit|push)([^[:alnum:]_-]|$)' <<<"$cmd"; then
  echo "agent-token repo: commit with agent-commit, which also pushes; not git commit or git push. For new executables, mode changes or force pushes, ask the user." >&2
  exit 2
fi
# In the agent devcontainer gh already is the wrapper and agent-gh does not exist.
if command -v agent-gh >/dev/null && grep -Eq '(^|[;&|({[:space:]])gh([[:space:]]|$)' <<<"$cmd"; then
  echo "agent-token repo: use agent-gh instead of gh, so GitHub sees the agent app, not the user." >&2
  exit 2
fi
