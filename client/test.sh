#!/usr/bin/env bash
# Checks agent-token --permissions against a fake broker. Run: bash client/test.sh (needs jq, python3).
set -euo pipefail
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
at() { TOKEN_BROKER_URL=http://127.0.0.1:$1 "$(dirname "$0")/bin/agent-token" "${@:2}"; }
cache=$dir/agent-token/repos/acme__app.json

[[ $(at 18081 acme/app) == ghs_fake ]] || fail "token"
[[ $(at 18082 --permissions acme/app | jq -c .) == '{"contents":"write","actions":"write"}' ]] || fail "permissions from cache"
jq '.permissions = null' "$cache" >"$dir/x" && mv "$dir/x" "$cache"
[[ $(at 18081 --permissions acme/app | jq -r .actions) == write ]] || fail "cache without permissions mints anew"
rm "$cache"
at 18082 --permissions acme/app 2>/dev/null && fail "broker without permissions accepted"
[[ $(at 18082 acme/app) == ghs_fake ]] || fail "token after broker without permissions"
echo "client tests passed"
