#!/usr/bin/env bash
# Runs on the host before the container is created (initializeCommand): writes the broker config
# from the Actions variables AGENT_TOKEN_BROKER_URL and AGENT_LOGIN_CLIENT_ID to .devcontainer/.env.
# Repo variables override org variables. Needs gh and jq on the host; see docs/containers.md.
set -euo pipefail
cd "$(dirname "$0")"
# Inside the container no token may read variables, so this has to run on the host.
org=$(gh api --paginate 'repos/{owner}/{repo}/actions/organization-variables' --jq '.variables[]')
repo=$(gh api --paginate 'repos/{owner}/{repo}/actions/variables' --jq '.variables[]')
vars=$(jq -s 'map({(.name): .value}) | add // {}' <<<"$org$repo")
url=$(jq -r '.AGENT_TOKEN_BROKER_URL // empty' <<<"$vars")
id=$(jq -r '.AGENT_LOGIN_CLIENT_ID // empty' <<<"$vars")
if [[ -z $url || -z $id ]]; then
  echo "broker-env: set the Actions variables AGENT_TOKEN_BROKER_URL and AGENT_LOGIN_CLIENT_ID (org or repo)" >&2
  exit 1
fi
# Rewritten on every build, so edits the agent makes to .env do not survive a rebuild.
printf 'TOKEN_BROKER_URL=%s\nLOGIN_APP_CLIENT_ID=%s\n' "$url" "$id" >.env
