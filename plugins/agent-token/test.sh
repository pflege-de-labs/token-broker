#!/usr/bin/env bash
# Checks which commands guard.sh blocks and what session-start.sh tells Claude; no network, gh is a stub.
set -euo pipefail
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR=$tmp PATH="$tmp/bin:$PATH"
mkdir -p "$tmp/bin" "$tmp/claude-agent-token"
echo org/repo >"$tmp/claude-agent-token/marked"

# The stub gh answers `repo view` and the org variable lookup.
cat >"$tmp/bin/gh" <<'EOF'
#!/bin/sh
case $1 in
  # With STUB_DIR set, only that folder is the repo.
  repo) [ -z "${STUB_DIR-}" ] || [ "$PWD" = "$STUB_DIR" ] && echo "${STUB_REPO-org/repo}" ;;
  api) printf '%s\n' "${STUB_URL-https://broker.example/x}" ;;
esac
EOF
chmod 755 "$tmp/bin/gh"
# Unmarked sessions recheck the topic; for these the repo has none.
export STUB_REPO=
fail=0
input() { printf '{"session_id": "%s", "cwd": "%s", "tool_input": {"command": %s}}' "$1" "${3-}" "$(jq -n --arg c "$2" '$c')"; }
run() { # session, command, expected exit code
  local got=0
  input "$1" "$2" | hooks/guard.sh 2>/dev/null || got=$?
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

# Without jq the guard cannot read the command, so it blocks in marked sessions only.
mkdir "$tmp/nojq"
for c in bash cat grep; do ln -s "$(command -v $c)" "$tmp/nojq/$c"; done
nojq() { # session, expected exit code
  local got=0
  input "$1" 'git status' | PATH=$tmp/nojq hooks/guard.sh 2>/dev/null || got=$?
  [[ $got == "$2" ]] || { echo "FAIL without jq ($1): exit $got, want $2"; fail=1; }
}
nojq marked 2
nojq other 0

# App installed after SessionStart: the first guarded command marks the session and blocks.
late() { # session, command, expected exit code, then env assignments
  local got=0
  input "$1" "$2" | env -u TOKEN_BROKER_URL -u CLAUDE_PLUGIN_OPTION_BROKER_URL "${@:4}" XDG_CACHE_HOME="$tmp/cache" hooks/guard.sh 2>"$tmp/err" || got=$?
  [[ $got == "$3" ]] || { echo "FAIL late ($1) '$2': exit $got, want $3: $(cat "$tmp/err")"; fail=1; }
}
echo "$tmp/late-env" >"$tmp/claude-agent-token/late.env"
late late 'git status' 0 STUB_REPO=org/repo
[[ ! -e $tmp/claude-agent-token/late ]] || { echo "FAIL late: unguarded command marked the session"; fail=1; }
late late 'git commit -m x' 2 STUB_REPO=org/repo
grep -q 'GitHub access in org/repo' "$tmp/err" || { echo "FAIL late: no context: $(cat "$tmp/err")"; fail=1; }
[[ -f $tmp/claude-agent-token/late ]] || { echo "FAIL late: session not marked"; fail=1; }
grep -qx 'export TOKEN_BROKER_URL=https://broker.example/x' "$tmp/late-env" || { echo "FAIL late env file"; fail=1; }
late late 'agent-commit -m x' 0
late late2 'gh pr list' 0
[[ ! -e $tmp/claude-agent-token/late2 ]] || { echo "FAIL late2: marked without topic"; fail=1; }
# Session started in a parent folder: the guard rechecks the folder the command targets.
mkdir -p "$tmp/ws/repo"
cwd() { # session, command, expected exit code
  local got=0
  input "$1" "$2" "$tmp/ws" | env -u TOKEN_BROKER_URL STUB_REPO=org/repo STUB_DIR="$tmp/ws/repo" XDG_CACHE_HOME="$tmp/cache" hooks/guard.sh 2>"$tmp/err" || got=$?
  [[ $got == "$3" ]] || { echo "FAIL cwd ($1) '$2': exit $got, want $3: $(cat "$tmp/err")"; fail=1; }
}
cwd ws1 'git push' 0
cwd ws2 'cd repo && git push' 2
cwd ws3 'git -C repo push' 2
cwd ws4 'cd "repo"; gh pr list' 2
cwd ws5 'cd elsewhere && git push' 0
unset STUB_REPO

# session-start.sh
start() { # expected output pattern, then env assignments
  local out
  out=$(env -u TOKEN_BROKER_URL -u CLAUDE_PLUGIN_OPTION_BROKER_URL "${@:2}" CLAUDE_ENV_FILE="$tmp/env" XDG_CACHE_HOME="$tmp/cache" hooks/session-start.sh <<<'{"session_id": "s1"}')
  grep -Eq "$1" <<<"$out" || { echo "FAIL session-start ${*:2}: want /$1/, got: $out"; fail=1; }
}
start 'GitHub access in org/repo'
grep -qx 'export TOKEN_BROKER_URL=https://broker.example/x' "$tmp/env" || { echo "FAIL env file: $(cat "$tmp/env")"; fail=1; }
[[ -f $tmp/claude-agent-token/s1 ]] || { echo "FAIL session not marked"; fail=1; }
grep -qx "$tmp/env" "$tmp/claude-agent-token/s1.env" || { echo "FAIL env file path not saved for guard.sh"; fail=1; }
rm "$tmp/env"
start 'GitHub access' CLAUDE_PLUGIN_OPTION_BROKER_URL=https://option.example STUB_URL=
grep -qx 'export TOKEN_BROKER_URL=https://option.example' "$tmp/env" || { echo "FAIL option URL: $(cat "$tmp/env")"; fail=1; }
rm "$tmp/env"
start 'GitHub access' TOKEN_BROKER_URL=https://env.example STUB_URL=
[[ ! -e $tmp/env ]] || { echo "FAIL env file written although TOKEN_BROKER_URL was set"; fail=1; }
start 'broker URL is unknown' STUB_URL=
# shellcheck disable=SC2016 # literal value the hook must refuse
start 'broker URL is unknown' 'STUB_URL=https://x.example/$(id)'
[[ ! -e $tmp/env ]] || { echo "FAIL env file written for a bad URL: $(cat "$tmp/env")"; fail=1; }
out=$(STUB_REPO='' hooks/session-start.sh <<<'{"session_id": "s2"}')
[[ -z $out && ! -e $tmp/claude-agent-token/s2 ]] || { echo "FAIL repo without topic: $out"; fail=1; }
exit $fail
