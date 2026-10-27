#!/usr/bin/env bash
# Links the agent scripts from the checkout, so edits to them apply without a rebuild.
set -euo pipefail
ws=$(git rev-parse --show-toplevel)
# ~/.local/bin, not /usr/local/bin: vscode has no sudo beyond the firewall script.
ln -sf "$ws/agent-token" "$ws/agent-token-git-credential" "$ws/agent-github-mcp" ~/.local/bin/
# Ahead of /usr/bin/gh in PATH; the wrapper finds the real gh itself.
ln -sf "$ws/agent-gh" ~/.local/bin/gh
mise trust "$ws/mise.toml"
mise install
