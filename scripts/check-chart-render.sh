#!/usr/bin/env bash
# Asserts what the chart renders; rendering alone proves only that it is not broken.
set -euo pipefail

chart=${1:-charts/token-broker}
fail() { echo "::error::$1"; exit 1; }

default=$(helm template token-broker "$chart" --values "$chart/ci/default-values.yaml")

# The image default must track this repository.
echo "$default" | grep -q '"ghcr.io/pflege-de/token-broker:' \
  || fail "image default does not point at ghcr.io/pflege-de/token-broker"

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

# Missing credentials must fail the render, not deploy a broker that crashes on start.
if helm template token-broker "$chart" >/dev/null 2>&1; then
  fail "chart renders without required config"
fi
if helm template token-broker "$chart" --values "$chart/ci/default-values.yaml" \
     --set secret.privateKey= >/dev/null 2>&1; then
  fail "chart renders without a private key"
fi

echo "chart render assertions passed"
