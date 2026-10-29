---
title: Install script
weight: 3
---

Install the client scripts from a release tarball, without a package manager.

```sh
curl -fsSL https://raw.githubusercontent.com/pflege-de-labs/token-broker/main/scripts/install.sh | bash
```

The script:

* downloads `agent-token-<version>.tar.gz` from the release and verifies its sha256 against the
  release's `checksums.txt`;
* installs the scripts into `$PREFIX/bin`, `PREFIX` defaulting to `~/.local`;
* installs `agent-gh` as `agent-gh`, never as `gh` on the host;
* never changes your global git config.

Make sure `$PREFIX/bin` is on your `PATH`.

## Pin a version

```sh
curl -fsSL https://raw.githubusercontent.com/pflege-de-labs/token-broker/main/scripts/install.sh \
  | bash -s -- --version v0.6.0
```

## Choose the install directory

```sh
curl -fsSL https://raw.githubusercontent.com/pflege-de-labs/token-broker/main/scripts/install.sh \
  | PREFIX=/opt/agent bash
```

Every `v*` release carries `agent-token-<version>.tar.gz` (the scripts in `bin/`) and
`checksums.txt`. The script needs `bash`, `curl` and `jq`; `gh` is needed for `agent-gh`.
