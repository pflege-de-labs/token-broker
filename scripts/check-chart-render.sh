#!/usr/bin/env bash
# Asserts what the chart renders; rendering alone proves only that it is not broken.
set -euo pipefail

chart=${1:-charts/token-broker}
fail() { echo "::error::$1"; exit 1; }

default=$(helm template token-broker "$chart" --values "$chart/ci/default-values.yaml")

# The image default must track this repository.
echo "$default" | grep -q '"ghcr.io/pflege-de-labs/token-broker:' \
  || fail "image default does not point at ghcr.io/pflege-de-labs/token-broker"

# The pod holds the app key; it must not also hold a Kubernetes API token or a writable root.
echo "$default" | grep -q "automountServiceAccountToken: false" \
  || fail "service account token is automounted"
echo "$default" | grep -q "readOnlyRootFilesystem: true" \
  || fail "root filesystem is writable"
echo "$default" | grep -q "runAsNonRoot: true" \
  || fail "pod may run as root"
# Without it the non-root process cannot read the root-owned key file and crash-loops.
echo "$default" | grep -q "fsGroup: 65532" \
  || fail "fsGroup missing, the key file is unreadable for uid 65532"

# The key path the binary reads must be the file the volume projects.
echo "$default" | grep -q "value: /etc/token-broker/private-key.pem" \
  || fail "GITHUB_APP_PRIVATE_KEY_FILE does not point at the mounted key"
echo "$default" | grep -q "path: private-key.pem" \
  || fail "private key is not projected into the volume"

# An out-of-band Secret must suppress the chart's own and be the one referenced.
existing=$(helm template token-broker "$chart" --values "$chart/ci/existing-secret-values.yaml")
if echo "$existing" | grep -q "^kind: Secret$"; then
  fail "chart rendered its own Secret despite existingSecret"
fi
[ "$(echo "$existing" | grep -c "token-broker-credentials")" -eq 2 ] \
  || fail "existingSecret is not used for both the key volume and the client secret"

# extraObjects render, and through tpl, so they can follow the release namespace.
extra=$(helm template token-broker "$chart" --namespace ai --values "$chart/ci/extra-objects-values.yaml")
echo "$extra" | grep -q "^kind: SealedSecret$" \
  || fail "extraObjects are not rendered"
echo "$extra" | grep -A4 "^kind: SealedSecret$" | grep -qE "namespace: '?ai'?$" \
  || fail "extraObjects are not run through tpl"

# The public route must expose exactly POST <path> -> /token/actions, nothing else.
actions=$(helm template token-broker "$chart" --values "$chart/ci/actions-route-values.yaml" \
  --show-only templates/httproute-actions.yaml)
[ "$(echo "$actions" | grep -c "value: ")" -eq 1 ] \
  || fail "public route matches more than one path"
echo "$actions" | grep -q 'value: "/broker/token/actions"' \
  || fail "public route does not match the configured path"
echo "$actions" | grep -q "method: POST" \
  || fail "public route is not restricted to POST"
echo "$actions" | grep -q "replaceFullPath: /token/actions" \
  || fail "public route does not rewrite to the Actions-only endpoint"
if helm template token-broker "$chart" --values "$chart/ci/default-values.yaml" \
     --set actionsRoute.enabled=true >/dev/null 2>&1; then
  fail "public route renders without parentRefs"
fi

# Actions allowlists stay off by default and reach the broker as comma-separated env vars.
if echo "$default" | grep -q "ACTIONS_ALLOWED_"; then
  fail "Actions allowlists set without being configured"
fi
lists=$(helm template token-broker "$chart" --values "$chart/ci/default-values.yaml" \
  --set 'config.actionsOidc.allowedRefs={refs/heads/main,refs/tags/*}' \
  --set 'config.actionsOidc.allowedWorkflows={acme/wf/.github/workflows/agent.yml@*}')
echo "$lists" | grep -A1 "name: ACTIONS_ALLOWED_REFS" | grep -q 'value: "refs/heads/main,refs/tags/\*"' \
  || fail "allowedRefs not rendered as ACTIONS_ALLOWED_REFS"
echo "$lists" | grep -A1 "name: ACTIONS_ALLOWED_WORKFLOWS" | grep -q 'value: "acme/wf/.github/workflows/agent.yml@\*"' \
  || fail "allowedWorkflows not rendered as ACTIONS_ALLOWED_WORKFLOWS"

# Agent permissions stay at the broker defaults unless configured, rendered as name:level pairs.
if echo "$default" | grep -q "AGENT_PERMISSIONS"; then
  fail "AGENT_PERMISSIONS set without being configured"
fi
helm template token-broker "$chart" --values "$chart/ci/default-values.yaml" \
  --set config.agentPermissions.contents=write --set config.agentPermissions.actions=write \
  | grep -A1 "name: AGENT_PERMISSIONS" | grep -q 'value: "actions:write,contents:write"' \
  || fail "agentPermissions not rendered as AGENT_PERMISSIONS"

# Missing credentials must fail the render, not deploy a broker that crashes on start.
if helm template token-broker "$chart" >/dev/null 2>&1; then
  fail "chart renders without required config"
fi
if helm template token-broker "$chart" --values "$chart/ci/default-values.yaml" \
     --set secret.privateKey= >/dev/null 2>&1; then
  fail "chart renders without a private key"
fi

echo "chart render assertions passed"
