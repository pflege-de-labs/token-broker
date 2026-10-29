---
title: Kubernetes
weight: 6
---

Deploy the broker with the Helm chart. Create the two GitHub Apps first, as described in
[Set up the GitHub Apps](../../guides/github-apps/).

The image is `ghcr.io/pflege-de-labs/token-broker`; the chart is published to
`oci://ghcr.io/pflege-de-labs/charts/token-broker`. The chart has no deployment-specific defaults.

## 1. Create the Secret

```sh
kubectl create secret generic token-broker-credentials \
  --from-file=private-key.pem=<agent-app>.private-key.pem \
  --from-literal=login-client-secret="$LOGIN_CLIENT_SECRET"
```

## 2. Write the values

```yaml
existingSecret: token-broker-credentials
config:
  appId: "<agent app ID>"
  org: my-org
  loginClientId: "<login app client ID>"
```

`config.org` is a comma-separated list; only repositories of these organizations get tokens.

## 3. Install

```sh
helm install token-broker oci://ghcr.io/pflege-de-labs/charts/token-broker \
  --namespace token-broker --create-namespace -f values.yaml
```

## 4. Expose it

Developers and runners with internal network access reach the broker through `ingress` or
`httpRoute`. Keep that route internal: the device-flow client ID is public, so a reachable broker
invites phishing. Workflows on GitHub-hosted runners need the public `actionsRoute`, which
forwards only `POST` on one path to `/token/actions`
([details](../../guides/actions/)).

The broker needs outbound access to `api.github.com` and `token.actions.githubusercontent.com`
only; GitHub never calls it. Run it behind TLS.

Check it with `GET /healthz` and `GET /readyz`; `/readyz` succeeds when GitHub accepts the app key.
See [Helm values](../../reference/helm-values/) and
[broker configuration](../../reference/broker-config/).
