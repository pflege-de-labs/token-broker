---
title: Kubernetes
weight: 6
---

Deployen Sie den Broker mit dem Helm-Chart. Legen Sie zuerst die beiden GitHub-Apps an, wie unter
[GitHub-Apps einrichten](../../guides/github-apps/) beschrieben.

Das Image ist `ghcr.io/pflege-de-labs/token-broker`; das Chart wird unter
`oci://ghcr.io/pflege-de-labs/charts/token-broker` veröffentlicht. Das Chart hat keine
deployment-spezifischen Defaults.

## 1. Secret anlegen {#1-create-the-secret}

```sh
kubectl create secret generic token-broker-credentials \
  --from-file=private-key.pem=<agent-app>.private-key.pem \
  --from-literal=login-client-secret="$LOGIN_CLIENT_SECRET"
```

## 2. Values schreiben {#2-write-the-values}

```yaml
existingSecret: token-broker-credentials
config:
  appId: "<agent app ID>"
  org: my-org
  loginClientId: "<login app client ID>"
```

`config.org` ist eine kommagetrennte Liste; nur Repositories dieser Organisationen bekommen Tokens.

## 3. Installieren {#3-install}

```sh
helm install token-broker oci://ghcr.io/pflege-de-labs/charts/token-broker \
  --namespace token-broker --create-namespace -f values.yaml
```

## 4. Erreichbar machen {#4-expose-it}

Entwickler und Runner mit Zugang zum internen Netz erreichen den Broker über `ingress` oder
`httpRoute`. Halten Sie diese Route intern: Die Client-ID des Device Flows ist öffentlich, ein
erreichbarer Broker lädt daher zu Phishing ein. Workflows auf GitHub-gehosteten Runnern brauchen
die öffentliche `actionsRoute`, die nur `POST` auf einem Pfad an `/token/actions` weiterleitet
([Details](../../guides/actions/)).

Der Broker braucht ausgehenden Zugriff nur auf `api.github.com` und
`token.actions.githubusercontent.com`; GitHub ruft ihn nie auf. Betreiben Sie ihn hinter TLS.

Prüfen Sie ihn mit `GET /healthz` und `GET /readyz`; `/readyz` gelingt, wenn GitHub den App-Schlüssel
akzeptiert. Siehe [Helm-Values](../../reference/helm-values/) und
[Broker-Konfiguration](../../reference/broker-config/).
