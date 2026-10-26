#!/usr/bin/env bash
# Links the agent scripts from the checkout, so edits to them apply without a rebuild.
set -euo pipefail
ws=$(git rev-parse --show-toplevel)
sudo ln -sf "$ws/agent-token" "$ws/agent-token-git-credential" "$ws/agent-github-mcp" /usr/local/bin/
# Ahead of /usr/bin/gh in PATH; the wrapper finds the real gh itself.
sudo ln -sf "$ws/agent-gh" /usr/local/bin/gh
sudo chown vscode: ~/.cache/agent-token ~/.local/share/mise
mise trust "$ws/mise.toml"
mise install
