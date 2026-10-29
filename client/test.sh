#!/usr/bin/env bash
# Checks agent-token --permissions against a fake broker. Run: bash client/test.sh (needs jq, python3).
set -euo pipefail
# Absolute, because the gh checks run from another directory.
bin=$(cd "$(dirname "$0")/bin" && pwd)
dir=$(mktemp -d)
pids=()
trap 'kill "${pids[@]}" 2>/dev/null; rm -rf "$dir"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# $1 port, $2 permissions JSON the broker returns (null: none, like brokers before 0.6.0).
fake_broker() {
  python3 - "$@" <<'PY' &
import http.server, json, sys
perms = json.loads(sys.argv[2])
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers["Content-Length"]))
        body = {"token": "ghs_fake", "expires_at": "2099-01-01T00:00:00Z"}
        if perms is not None:
            body["permissions"] = perms
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())
    def log_message(self, *a):
        pass
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
  pids+=($!)
}
fake_broker 18081 '{"contents":"write","actions":"write"}'
fake_broker 18082 null
sleep 1

export XDG_CACHE_HOME=$dir AGENT_TOKEN_NONINTERACTIVE=1
mkdir -p "$dir/agent-token"
echo '{"access_token":"ghu_x","expires_at":4102444800}' >"$dir/agent-token/login.json"
at() { TOKEN_BROKER_URL=http://127.0.0.1:$1 "$bin/agent-token" "${@:2}"; }
cache=$dir/agent-token/repos/acme__app.json

[[ $(at 18081 acme/app) == ghs_fake ]] || fail "token"
[[ $(at 18082 --permissions acme/app | jq -c .) == '{"contents":"write","actions":"write"}' ]] || fail "permissions from cache"
jq '.permissions = null' "$cache" >"$dir/x" && mv "$dir/x" "$cache"
[[ $(at 18081 --permissions acme/app | jq -r .actions) == write ]] || fail "cache without permissions mints anew"
rm "$cache"
at 18082 --permissions acme/app 2>/dev/null && fail "broker without permissions accepted"
[[ $(at 18082 acme/app) == ghs_fake ]] || fail "token after broker without permissions"
# gh wrapper: a fake real gh behind it records what reaches it.
mkdir -p "$dir/wrap" "$dir/real" "$dir/nogit"
cp "$bin/agent-gh" "$dir/wrap/gh"
printf '#!/bin/sh\necho "real gh $*" >>"%s/real.log"\n' "$dir" >"$dir/real/gh"
chmod 755 "$dir/wrap/gh" "$dir/real/gh"
gh() { (cd "$dir/nogit" && PATH="$dir/wrap:$bin:$dir/real:$PATH" TOKEN_BROKER_URL=http://127.0.0.1:18081 GH_REPO="" command gh "$@"); }
for sub in login refresh setup-git; do
  gh auth "$sub" 2>/dev/null && fail "gh auth $sub allowed"
done
[[ ! -e $dir/real.log ]] || fail "disabled gh auth reached the real gh"
gh auth status 2>/dev/null || fail "gh auth status without repo while logged in"
rm "$dir/agent-token/login.json"
gh auth status 2>/dev/null && fail "gh auth status without repo while logged out"
gh pr list 2>/dev/null
grep -q "real gh pr list" "$dir/real.log" || fail "other commands without repo pass through"
echo "client tests passed"
