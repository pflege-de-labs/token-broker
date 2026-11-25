#!/usr/bin/env bash
# PreToolUse(Bash): in sessions session-start.sh marked, blocks commits, pushes and gh calls with the user's credentials.
# shortcut: matches the command text, so `env git push` or a script that pushes slip through; agent-run is the sandbox.
set -euo pipefail
input=$(cat)
re='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9-]+)"'
[[ $input =~ $re ]] || exit 0
mark=${TMPDIR:-/tmp}/claude-agent-token/${BASH_REMATCH[1]}
# Builtins only: the no-jq check below must still run with a bare PATH.
here=$(cd "${BASH_SOURCE[0]%/*}" && pwd)
# Any git options before the subcommand, e.g. --no-pager or -c k=v.
commit_re='(^|[^[:alnum:]_-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+(commit|push)([^[:alnum:]_-]|$)'
# Also /opt/homebrew/bin/gh and \gh, not agent-gh.
gh_re='(^|[;&|({[:space:]/\\`"'\''])gh([[:space:]]|$)'
write_re='(^|[^[:alnum:]_-])agent-(commit|gh[[:space:]]+pr[[:space:]]+create)([^[:alnum:]_-]|$)'
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || cmd=${input//\"/ }
# gh in one standalone exec into a container is the container's gh: in the agent devcontainer, the wrapper (ADR 18).
# shortcut: trusts the container to be the agent devcontainer; probe its gh if other containers get gh credentials.
quoted_re="^([^']*)'[^']*'(.*)$"
# [:blank:], not [:space:]: a newline outside quotes starts a host command.
exec_re='^[[:blank:]]*(podman|docker|devcontainer)[[:blank:]]+exec[[:blank:]][[:alnum:][:blank:]_./:=@,+%-]*$'
leak_re='(GH|GITHUB)_TOKEN|--env-file|[/\\]gh([[:space:]]|$)'
gh_cmd=$cmd
host=$cmd
# Single-quoted text goes to the container as is; the host shell expands only the rest.
while [[ $host =~ $quoted_re ]]; do host="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"; done
if [[ $host =~ $exec_re && ! $cmd =~ $leak_re ]]; then gh_cmd=; fi
if [[ ! -f $mark ]]; then
  # The app may have been installed after SessionStart: recheck, but only for commands guarded below.
  # shortcut: one gh repo view per such command in other repos; add a negative cache if that is too slow.
  grep -Eq "$commit_re" <<<"$cmd" || grep -Eq "$gh_re" <<<"$gh_cmd" || exit 0
  cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null) || cwd=
  [[ -z $cwd ]] || cd "$cwd" 2>/dev/null || true
  # `cd repo && git push` and `git -C repo push` act on another repo than cwd; first one wins.
  dir_re='(^|[;&|({[:space:]])(cd|git[[:space:]]+-C)[[:space:]]+([^[:space:];&|)]+)'
  if [[ $cmd =~ $dir_re ]]; then dir=${BASH_REMATCH[3]//[\"\']/}; cd "${dir/#\~/$HOME}" 2>/dev/null || true; fi
  [[ ! -f $mark.env ]] || { CLAUDE_ENV_FILE=$(<"$mark.env"); export CLAUDE_ENV_FILE; }
  out=$("$here/session-start.sh" <<<"$input") || true
  # .unknown: gh could not read the topics of a GitHub repo, which may be an agent-token repo.
  [[ -f $mark || -f $mark.unknown ]] || exit 0
  { echo "Blocked: this repository may use the agent app, which the session start did not see."; echo "$out"; } >&2
  exit 2
fi
# Without jq the command cannot be read: block, since any other exit code lets it run.
command -v jq >/dev/null || { echo "agent-token repo: jq is missing, so commands cannot be checked; ask the user to install jq." >&2; exit 2; }

# Checked first: after a failed agent-commit, Claude would otherwise look for another way to push.
if { grep -Eq "$commit_re|$write_re" <<<"$cmd" || grep -Eq "$gh_re" <<<"$gh_cmd"; } &&
  # --check reads only the cache, but the script wants a URL before it parses flags.
  ! PATH="$here/../bin:$PATH" TOKEN_BROKER_URL=${TOKEN_BROKER_URL:-https://unused} agent-token --check 2>/dev/null; then
  echo "agent-token repo: the agent login is missing or expires within 5 minutes. Stop and ask the user to run \`! agent-token --login\`, then retry. Do not commit, push or open PRs any other way (git, gh, SSH or MCP)." >&2
  exit 2
fi
if grep -Eq "$commit_re" <<<"$cmd"; then
  echo "agent-token repo: commit with agent-commit, which also pushes; not git commit or git push. For new executables, mode changes or force pushes, ask the user." >&2
  exit 2
fi
# agent-gh ships in the plugin's bin/; inside the agent devcontainer gh itself is the wrapper.
if grep -Eq "$gh_re" <<<"$gh_cmd"; then
  echo "agent-token repo: use agent-gh instead of gh, so GitHub sees the agent app, not the user. In the agent devcontainer, run gh there in one standalone command: podman exec <container> bash -lc '<gh command>'. If that fails, ask the user; never fall back to gh." >&2
  exit 2
fi
