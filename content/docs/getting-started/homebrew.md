---
title: Homebrew
weight: 2
---

Install the client scripts on macOS or Linux with Homebrew. The formula depends on `jq` and `gh`.

```sh
brew tap pflege-de-labs/token-broker https://github.com/pflege-de-labs/token-broker
brew install agent-token
```

Set the broker URL and request a token:

```sh
export TOKEN_BROKER_URL=https://<broker>
agent-token my-org/my-repo    # prints a 1h agent token
```

The first run prints a code for <https://github.com/login/device>. The login token is cached for 8
hours in `~/.cache/agent-token/login.json` (mode 600), so later runs need no browser.

Homebrew installs a pinned release. To use the scripts from Claude Code without managing the
install yourself, use the [plugin](../claude-code/).

{{< callout type="info" >}}
Without a container, deny the agent read access to `~/.ssh`, `~/.config/gh` and
`~/.cache/agent-token`.
{{< /callout >}}

See [client commands](../../reference/client-cli/) for what each script does.
