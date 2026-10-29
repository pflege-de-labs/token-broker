#!/usr/bin/env bash
# Runs install.sh against a fake local release; no network.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

rel=$tmp/rel/v9.9.9
mkdir -p "$rel"
tar -C plugins/agent-token -czf "$rel/agent-token-9.9.9.tar.gz" bin
(cd "$rel" && { sha256sum agent-token-9.9.9.tar.gz 2>/dev/null || shasum -a 256 agent-token-9.9.9.tar.gz; } >checksums.txt)
inst() { TOKEN_BROKER_RELEASE_BASE=file://$tmp/rel PREFIX=$tmp/$1 bash scripts/install.sh --version v9.9.9 >/dev/null; }

inst ok || fail "install"
for f in agent-token agent-token-git-credential agent-gh agent-github-mcp agent-commit; do
  [[ -x $tmp/ok/bin/$f ]] || fail "$f not installed"
done
[[ ! -e $tmp/ok/bin/gh ]] || fail "agent-gh installed as gh"
[[ $("$tmp/ok/bin/agent-token" --version) == "agent-token dev" ]] || fail "--version of the installed agent-token"

echo "0000  agent-token-9.9.9.tar.gz" >"$rel/checksums.txt"
inst bad 2>/dev/null && fail "bad checksum accepted"
[[ ! -e $tmp/bad ]] || fail "files installed despite a bad checksum"
TOKEN_BROKER_RELEASE_BASE=file://$tmp/rel PREFIX=$tmp/x bash scripts/install.sh --version 'v1;id' 2>/dev/null && fail "bad tag accepted"
echo "install tests passed"
