# GitHub Apps

The broker needs two org-owned GitHub Apps in `pflege-de`. Settings live under
*Organization settings → Developer settings → GitHub Apps*.

| | Agent app (`pflege-de-agent`) | Login app (`pflege-de-agent-login`) |
|---|---|---|
| Purpose | Identity agents commit, push and open PRs as | Proves who a developer is (device flow) |
| Repository permissions | Contents RW, Pull requests RW, Issues RW, Metadata R | **none** |
| Organization / account permissions | none | none |
| Device flow | **off** | **on** |
| Installed | on selected repos | not needed |
| Broker config | `GITHUB_APP_ID`, private key | `LOGIN_APP_CLIENT_ID`, client secret |

## Agent app

- [ ] Owner is the `pflege-de` org, not a personal account.
- [ ] *Where can this app be installed:* **Only on this account**.
- [ ] *Webhook:* **Active unchecked**. The broker receives no events.
- [ ] *Identifying and authorizing users:* no callback URL, *Request user authorization (OAuth) during installation* off, **Enable Device Flow off**. User tokens of this app would act as the developer with write access.
- [ ] *Repository permissions:* Contents **Read and write**, Pull requests **Read and write**, Issues **Read and write**, Metadata **Read-only**. Everything else **No access**, in particular:
  - Workflows: so an agent cannot edit CI to escalate.
  - Administration, Secrets, Environments, Actions: no repo or secret management.
  - Checks/Statuses: so the agent cannot report a required check as green.
- [ ] *Organization* and *Account permissions:* all **No access**.
- [ ] *Subscribe to events:* none.
- [ ] *Private keys:* one key generated. It goes only into the broker Secret as `private-key.pem`, never into a repo secret or onto a laptop. Delete the downloaded file afterwards.
- [ ] *Install App* → `pflege-de` → **Only select repositories**: the repos agents may work on (none yet is fine).
  - Every repo it is installed on must require a **code owner review** on its default branch and have a `CODEOWNERS` file naming human teams. The app has contents write, so its approvals otherwise count toward required reviews; bots cannot be code owners.
- [ ] The app is **not** a bypass actor in any ruleset (repo or org). That includes `protect-default-branch` from github-ops.
- [ ] Note the **App ID** (`config.appId`).

The broker requests only the four permissions above per token, so granting more to the app widens nothing for agents. Still, keep the app minimal: the private key alone can mint tokens with everything the app has.

## Login app

- [ ] Owner is the `pflege-de` org; *Only on this account*.
- [ ] *Webhook:* **Active unchecked**.
- [ ] *Repository, Organization* and *Account permissions:* all **No access**.
- [ ] **Enable Device Flow on**.
- [ ] *Expire user authorization tokens* **on**: tokens live 8h.
- [ ] *Callback URL:* none needed for device flow (if the form insists, use the broker URL).
- [ ] *Request user authorization (OAuth) during installation* off; the app does not need to be installed.
- [ ] Note the **Client ID** (`config.loginClientId`; developers also set it as `LOGIN_APP_CLIENT_ID`).
- [ ] *Client secrets:* one secret generated. It goes only into the broker Secret as `login-client-secret`.

## Broker Secret

Prefer External Secrets; for a manual setup:

```bash
kubectl create secret generic token-broker-credentials \
  --from-file=private-key.pem=pflege-de-agent.private-key.pem \
  --from-literal=login-client-secret="$LOGIN_CLIENT_SECRET"
```

Chart values:

```yaml
existingSecret: token-broker-credentials
config:
  appId: "<agent app ID>"
  org: pflege-de
  loginClientId: "<login app client ID>"
```

## Commit identity of the agent

The bot's commit email uses the **bot user ID**, not the App ID:

```bash
id=$(gh api "/users/pflege-de-agent%5Bbot%5D" --jq .id)
echo "pflege-de-agent[bot] <${id}+pflege-de-agent[bot]@users.noreply.github.com>"
```

Commits created through the API with an installation token are signed by GitHub and
attributed to this identity automatically.

## Rotation

- Agent app private key: generate a new key, update the Secret, roll the broker (the chart's checksum annotation only covers a chart-managed Secret), then delete the old key.
- Login app client secret: same order. Developer login tokens stay valid; they are checked against the app, not the secret.
