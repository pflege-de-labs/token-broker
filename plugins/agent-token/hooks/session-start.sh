#!/usr/bin/env bash
# SessionStart: github-ops sets the topic agent-token-broker on every repo the agent app is installed on.
# Prints context for Claude only in those repos; silent elsewhere and when gh cannot answer.
set -euo pipefail
sid=$(jq -r '.session_id // empty')
repo=$(gh repo view --json nameWithOwner,repositoryTopics \
  --jq 'select(any(.repositoryTopics[]?; .name == "agent-token-broker")) | .nameWithOwner' 2>/dev/null) || exit 0
[[ -n $repo ]] || exit 0
# guard.sh blocks git commit/push and gh for marked sessions.
if [[ $sid =~ ^[A-Za-z0-9-]+$ ]]; then
  mkdir -p "${TMPDIR:-/tmp}/claude-agent-token"
  echo "$repo" >"${TMPDIR:-/tmp}/claude-agent-token/$sid"
fi

if ! command -v agent-token >/dev/null; then
  echo "$repo uses token-broker agent tokens, but agent-token is not on PATH (setup: https://github.com/pflege-de-labs/devcontainer-features#on-the-host)."
  echo "Do not commit, push or write to GitHub until the user has set it up."
  exit 0
fi
echo "# GitHub access in $repo"
cat "$(dirname "${BASH_SOURCE[0]}")/agent-token.md"
agent-token --check 2>&1 || true
