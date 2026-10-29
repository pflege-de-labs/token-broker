#!/usr/bin/env bash
# SessionStart: github-ops sets the topic agent-token-broker on every repo the agent app is installed on.
# Prints context for Claude only in those repos; silent elsewhere and when gh cannot answer.
set -euo pipefail
# The plugin's bin/ is on the Bash tool's PATH, but hooks are not promised it.
PATH="$(dirname "${BASH_SOURCE[0]}")/../bin:$PATH"
docs=https://pflege-de-labs.github.io/token-broker/docs/getting-started/claude-code/
input=$(cat)
repo=$(gh repo view --json nameWithOwner,repositoryTopics \
  --jq 'select(any(.repositoryTopics[]?; .name == "agent-token-broker")) | .nameWithOwner' 2>/dev/null) || exit 0
[[ -n $repo ]] || exit 0
# guard.sh blocks git commit/push and gh for marked sessions. Parsed without jq, so a missing jq still marks.
re='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9-]+)"'
if [[ $input =~ $re ]]; then
  mkdir -p "${TMPDIR:-/tmp}/claude-agent-token"
  echo "$repo" >"${TMPDIR:-/tmp}/claude-agent-token/${BASH_REMATCH[1]}"
fi

stop() {
  echo "$repo uses token-broker agent tokens, but $1 (setup: $docs)."
  echo "Do not commit, push or write to GitHub until the user has fixed that."
  exit 0
}
missing=
for cmd in jq curl git agent-token; do command -v "$cmd" >/dev/null || missing+=" $cmd"; done
[[ -z $missing ]] || stop "these commands are missing:$missing"

if [[ -z ${TOKEN_BROKER_URL:-} ]]; then
  url=${CLAUDE_PLUGIN_OPTION_BROKER_URL:-}
  # Org variable only: a repo variable would let any repo admin send developer logins to their own server.
  [[ -n $url ]] || url=$(gh api --paginate "repos/$repo/actions/organization-variables" \
    --jq '.variables[] | select(.name == "AGENT_TOKEN_BROKER_URL") | .value' 2>/dev/null) || url=
  # Also keeps the export line below free of shell syntax.
  [[ $url =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~/-]*)?$ ]] ||
    stop "the broker URL is unknown: set the plugin option broker_url in /config, or the org variable AGENT_TOKEN_BROKER_URL"
  export TOKEN_BROKER_URL=$url
  # Later Bash tool commands source this file.
  [[ -z ${CLAUDE_ENV_FILE:-} ]] || echo "export TOKEN_BROKER_URL=$url" >>"$CLAUDE_ENV_FILE"
fi

echo "# GitHub access in $repo"
cat "$(dirname "${BASH_SOURCE[0]}")/agent-token.md"
agent-token --check 2>&1 || true
