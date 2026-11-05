#!/usr/bin/env bash
# Live test for agent-commit: needs agent-token logged in and write access to <org/repo>.
# Usage: client/agent-commit-live.sh org/repo  — works on a throwaway branch and deletes it afterwards.
set -euo pipefail
repo=${1:?usage: client/agent-commit-live.sh org/repo}
PATH=$(cd "$(dirname "$0")/../plugins/agent-token/bin" && pwd):$PATH
token=$(AGENT_TOKEN_NONINTERACTIVE=1 agent-token "$repo")
gh_api() { curl -fsS -H "Authorization: Bearer $token" "https://api.github.com/repos/$repo/$1" "${@:2}"; }
branch=test/agent-commit-$(date +%s)
dir=$(mktemp -d)
trap 'gh_api "git/refs/heads/$branch" -X DELETE || true; rm -rf "$dir"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

git clone -q --depth 1 "https://github.com/$repo" "$dir"
cd "$dir"
git switch -q -c "$branch"
victim=$(git ls-files | head -1)

# New remote branch, addition, modification, deletion.
echo new >added.txt
echo more >>README.md
git rm -q "$victim"
git add added.txt README.md
agent-commit -m "test: first" -m "body line"
[[ $(git rev-parse HEAD) == $(git rev-parse "origin/$branch") ]] || fail "HEAD not on origin"
[[ -z $(git status --porcelain) ]] || fail "worktree not clean"
[[ $(gh_api "commits/$(git rev-parse HEAD)" | jq .commit.verification.verified) == true ]] || fail "not verified"
[[ $(git log -1 --format=%b) == "body line" ]] || fail "body lost"

# Existing remote branch.
echo again >>added.txt
git add added.txt
agent-commit -m "test: second"
[[ $(git rev-parse HEAD~1) == $(git rev-parse "origin/$branch~1") && $(git rev-parse HEAD) == $(git rev-parse "origin/$branch") ]] ||
  fail "second commit not on origin"

# Over AGENT_COMMIT_MAX_BYTES: one commit per file, "(part i/n)" on all but the last.
base=$(git rev-parse HEAD)
for i in 1 2 3; do echo "part $i" >"split$i.txt"; done
git add split1.txt split2.txt split3.txt
AGENT_COMMIT_MAX_BYTES=1 agent-commit -m "test: split" -m "Trailer: kept"
[[ $(git rev-list --count "$base..HEAD") == 3 ]] || fail "split did not make 3 commits"
[[ $(git rev-parse HEAD) == $(git rev-parse "origin/$branch") ]] || fail "split HEAD not on origin"
[[ -z $(git status --porcelain) ]] || fail "worktree not clean after split"
[[ $(git log --format=%s "$base..HEAD" | tr '\n' '|') == "test: split|test: split (part 2/3)|test: split (part 1/3)|" ]] ||
  fail "split subjects: $(git log --format=%s "$base..HEAD")"
[[ $(git log -1 --format=%b HEAD~1) == "Trailer: kept" ]] || fail "split body lost"
for c in $(git rev-list "$base..HEAD"); do
  [[ $(gh_api "commits/$c" | jq .commit.verification.verified) == true ]] || fail "split commit $c not verified"
done

# A new executable would silently lose +x.
printf '#!/bin/sh\n' >run.sh && chmod +x run.sh && git add run.sh
agent-commit -m "test: exec" 2>/dev/null && fail "accepted a new executable"
git reset -q run.sh && rm run.sh

# Local commits ahead of origin cannot be replayed.
git commit -q --allow-empty -m local
echo x >>added.txt && git add added.txt
agent-commit -m "test: ahead" 2>/dev/null && fail "accepted a local commit ahead of origin"

echo "agent-commit: all tests passed"
