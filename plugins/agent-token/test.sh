#!/usr/bin/env bash
# Checks which commands guard.sh blocks; no network, gh and agent-gh are stubs.
set -euo pipefail
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR=$tmp PATH="$tmp/bin:$PATH"
mkdir -p "$tmp/bin" "$tmp/claude-agent-token"
printf '#!/bin/sh\n' >"$tmp/bin/agent-gh"
chmod 755 "$tmp/bin/agent-gh"
echo org/repo >"$tmp/claude-agent-token/marked"

fail=0
run() { # session, command, expected exit code
  local got=0
  jq -n --arg s "$1" --arg c "$2" '{session_id: $s, tool_input: {command: $c}}' | hooks/guard.sh 2>/dev/null || got=$?
  [[ $got == "$3" ]] || { echo "FAIL ($1) '$2': exit $got, want $3"; fail=1; }
}
run marked 'git commit -m x' 2
run marked 'git -C /src/x push origin main' 2
run marked 'git add -A && git commit -F msg' 2
run marked 'gh pr create --fill' 2
# shellcheck disable=SC2016 # literal command text
run marked 'x=$(gh api user)' 2
run marked 'agent-commit -m x' 0
run marked 'agent-gh pr create --fill' 0
run marked 'git status && git log' 0
run marked 'git commit-tree HEAD^{tree}' 0
run other 'git push' 0
run '../x' 'git push' 0
rm "$tmp/bin/agent-gh"
run marked 'gh pr view' 0
exit $fail
