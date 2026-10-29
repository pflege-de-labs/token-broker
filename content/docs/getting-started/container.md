---
title: Container
weight: 4
---

`agent-run` starts Claude Code in a container whose only GitHub credential is an agent token for
one repository. Your SSH keys, `gh` login, git config and the broker login token stay on the host.

## Before you start

* `podman`, `curl`, `jq` and `git` on the host.
* `agent-token` on your `PATH` ([Homebrew](../homebrew/) or [install script](../install-script/)).
* A clone of the [token-broker repository](https://github.com/pflege-de-labs/token-broker), which
  holds `agent-run` and the image definition in `container/`.

## Build the image

```sh
podman build -t localhost/agent-sandbox:latest container/
```

## Configure

```sh
export TOKEN_BROKER_URL=https://<broker>
export AGENT_APP_SLUG=<agent app slug>
export CLAUDE_CODE_OAUTH_TOKEN=<from `claude setup-token`>   # or ANTHROPIC_API_KEY
```

## Run

From inside a checkout (a clone or a git worktree):

```sh
/path/to/token-broker/agent-run                 # repository from the `origin` remote
/path/to/token-broker/agent-run my-org/my-repo  # explicit repository
/path/to/token-broker/agent-run -p "fix the failing test"   # arguments go to claude
```

`agent-run`:

* gets an agent token with `agent-token` (device flow on first use) and renews it every 45
  minutes while the session runs; the container reads it from a read-only file;
* mounts the checkout at the same path, plus the main repository's `.git` for worktrees;
* rewrites GitHub SSH remotes to HTTPS, so git pushes with the agent token;
* sets the commit identity to `<app>[bot] <<bot user ID>+<app>[bot]@users.noreply.github.com>`;
* keeps Claude Code's settings in the named volume `agent-claude`;
* maps your user to the container user, so files keep your ownership;
* installs the repository's toolchain from `mise.toml` or `.tool-versions` before Claude starts.

`AGENT_IMAGE` selects another image. `AGENT_PODMAN_ARGS` adds podman flags, for example
`--entrypoint sh` for a shell instead of Claude.

## Toolchains

The image holds only what every repository needs: git, `gh`, `jq`, `curl`, `make`, `unzip`,
ripgrep, shellcheck, python3 and [mise](https://mise.jdx.dev). Everything else comes from the
repository's mise config at its pinned versions. Installs and caches live in the volumes
`agent-mise` and `agent-cache`, so only the first session per version downloads. A repository
without a mise config gets no extra tools.

`agent-run` trusts the mise config of the mounted checkout only. A failed `mise install` prints a
warning and Claude starts anyway.

{{< callout type="warning" >}}
Never mount cloud credentials (`~/.aws`, kubeconfigs): they are developer credentials. Let the
agent write code and run `terraform plan` in CI instead.
{{< /callout >}}

## Limits

* The token covers one repository: fetching private dependencies from other repositories, such as
  Go modules, fails.
* Commits are unsigned; merge agent pull requests with squash.
* After 8 hours the login token expires and the next renewal prints a device code on the
  terminal.
