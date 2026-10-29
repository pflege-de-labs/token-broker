---
title: Set up the GitHub Apps
weight: 1
---

The broker needs two organization-owned GitHub Apps. Settings live under **Organization settings →
Developer settings → GitHub Apps**.

| | Agent app | Login app |
| --- | --- | --- |
| Purpose | Identity agents commit, push and open pull requests as | Proves who a developer is (device flow) |
| Repository permissions | Contents RW, Pull requests RW, Issues RW, Metadata R | none |
| Organization / account permissions | none | none |
| Device flow | off | on |
| Installed | on selected repositories | not needed |
| Broker config | `GITHUB_APP_ID`, private key | `LOGIN_APP_CLIENT_ID`, client secret |

## Agent app

* The owner is the organization, not a personal account. **Where can this app be installed:**
  only on this account.
* **Webhook:** active unchecked. The broker receives no events.
* **Identifying and authorizing users:** no callback URL, **Request user authorization (OAuth)
  during installation** off, **Enable Device Flow** off. User tokens of this app would act as the
  developer.
* **Repository permissions:** Contents, Pull requests and Issues **Read and write**, Metadata
  **Read-only**. Everything else **No access**, in particular:
  * Workflows, so an agent cannot edit CI to escalate.
  * Administration, Secrets, Environments and Actions, so it cannot manage repositories or
    secrets.
  * Checks and Statuses, so it cannot report a required check as green.
* **Organization** and **Account permissions:** all **No access**. **Subscribe to events:** none.
* **Private keys:** generate one key. It goes only into the broker Secret as `private-key.pem`,
  never into a repository secret or onto a laptop. Delete the downloaded file afterwards.
* **Install App** on **Only select repositories**: the repositories agents may work on.
* The app is **not** a bypass actor in any ruleset.
* Note the **App ID** (`config.appId`).

Every repository the app is installed on must also set [review rules](../review-rules/).

The broker requests only the four permissions per token, so granting more to the app widens
nothing for agents. `AGENT_PERMISSIONS` (chart: `config.agentPermissions`) changes that set; every
installation must have accepted each permission in it, or GitHub refuses the token. Keep the app
minimal: the private key alone can mint tokens with everything the app has.

## Login app

* The owner is the organization; install only on this account.
* **Webhook:** active unchecked.
* **Repository**, **Organization** and **Account permissions:** all **No access**.
* **Enable Device Flow** on. **Expire user authorization tokens** on: login tokens live 8 hours.
* Callback URL: none needed for device flow. If the form insists, use the broker URL.
* **Request user authorization (OAuth) during installation** off; the app need not be installed.
* Note the **Client ID** (`config.loginClientId`). The broker serves it to clients at
  `/login-app`.
* Generate one client secret. It goes only into the broker Secret as `login-client-secret`.

## Broker Secret and values

```sh
kubectl create secret generic token-broker-credentials \
  --from-file=private-key.pem=<agent-app>.private-key.pem \
  --from-literal=login-client-secret="$LOGIN_CLIENT_SECRET"
```

```yaml
existingSecret: token-broker-credentials
config:
  appId: "<agent app ID>"
  org: my-org
  loginClientId: "<login app client ID>"
```

Prefer an external secret manager over creating the Secret by hand.

## Commit identity of the agent

The bot's commit email uses the bot user ID, not the App ID:

```sh
id=$(gh api "/users/<app-slug>%5Bbot%5D" --jq .id)
echo "<app-slug>[bot] <${id}+<app-slug>[bot]@users.noreply.github.com>"
```

Commits created through the API with an installation token are signed by GitHub and attributed to
this identity automatically.

## Rotate credentials

* Agent app private key: generate a new key, update the Secret, roll the broker (the chart's
  checksum annotation only covers a chart-managed Secret), then delete the old key.
* Login app client secret: same order. Developer login tokens stay valid; they are checked
  against the app, not the secret.
