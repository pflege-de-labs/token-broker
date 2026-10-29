#!/usr/bin/env bash
# PreToolUse(Bash): in sessions session-start.sh marked, blocks commits, pushes and gh calls with the user's credentials.
# shortcut: matches the command text, so `env git push` or `/usr/bin/git push` slip through; agent-run is the sandbox.
set -euo pipefail
input=$(cat)
re='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9-]+)"'
[[ $input =~ $re && -f ${TMPDIR:-/tmp}/claude-agent-token/${BASH_REMATCH[1]} ]] || exit 0
# Without jq the command cannot be read: block, since any other exit code lets it run.
command -v jq >/dev/null || { echo "agent-token repo: jq is missing, so commands cannot be checked; ask the user to install jq." >&2; exit 2; }
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")

if grep -Eq '(^|[^[:alnum:]_-])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(commit|push)([^[:alnum:]_-]|$)' <<<"$cmd"; then
  echo "agent-token repo: commit with agent-commit, which also pushes; not git commit or git push. For new executables, mode changes or force pushes, ask the user." >&2
  exit 2
fi
# agent-gh ships in the plugin's bin/; in the agent devcontainer it also works, wrapping the gh wrapper.
if grep -Eq '(^|[;&|({[:space:]])gh([[:space:]]|$)' <<<"$cmd"; then
  echo "agent-token repo: use agent-gh instead of gh, so GitHub sees the agent app, not the user." >&2
  exit 2
fi
