#!/usr/bin/env bash
# PreToolUse(Bash): in sessions session-start.sh marked, blocks commits, pushes and gh calls with the user's credentials.
# shortcut: matches the command text, so `env git push` or `/usr/bin/git push` slip through; agent-run is the sandbox.
set -euo pipefail
input=$(cat)
re='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9-]+)"'
[[ $input =~ $re ]] || exit 0
mark=${TMPDIR:-/tmp}/claude-agent-token/${BASH_REMATCH[1]}
commit_re='(^|[^[:alnum:]_-])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(commit|push)([^[:alnum:]_-]|$)'
gh_re='(^|[;&|({[:space:]])gh([[:space:]]|$)'
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || cmd=${input//\"/ }
if [[ ! -f $mark ]]; then
  # The app may have been installed after SessionStart: recheck, but only for commands guarded below.
  # shortcut: one gh repo view per such command in other repos; add a negative cache if that is too slow.
  grep -Eq "$commit_re|$gh_re" <<<"$cmd" || exit 0
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null) || cwd=
  [[ -z $cwd ]] || cd "$cwd" 2>/dev/null || true
  # `cd repo && git push` and `git -C repo push` act on another repo than cwd; first one wins.
  dir_re='(^|[;&|({[:space:]])(cd|git[[:space:]]+-C)[[:space:]]+([^[:space:];&|)]+)'
  if [[ $cmd =~ $dir_re ]]; then dir=${BASH_REMATCH[3]//[\"\']/}; cd "${dir/#\~/$HOME}" 2>/dev/null || true; fi
  [[ ! -f $mark.env ]] || { CLAUDE_ENV_FILE=$(<"$mark.env"); export CLAUDE_ENV_FILE; }
  out=$("$here/session-start.sh" <<<"$input") || true
  [[ -f $mark ]] || exit 0
  { echo "Blocked: this repository uses the agent app, which the session start did not see."; echo "$out"; } >&2
  exit 2
fi
# Without jq the command cannot be read: block, since any other exit code lets it run.
command -v jq >/dev/null || { echo "agent-token repo: jq is missing, so commands cannot be checked; ask the user to install jq." >&2; exit 2; }

if grep -Eq "$commit_re" <<<"$cmd"; then
  echo "agent-token repo: commit with agent-commit, which also pushes; not git commit or git push. For new executables, mode changes or force pushes, ask the user." >&2
  exit 2
fi
# agent-gh ships in the plugin's bin/; in the agent devcontainer it also works, wrapping the gh wrapper.
if grep -Eq "$gh_re" <<<"$cmd"; then
  echo "agent-token repo: use agent-gh instead of gh, so GitHub sees the agent app, not the user." >&2
  exit 2
fi
