#!/usr/bin/env bash
# Installs the toolchain from mise.toml while the network is still open.
set -euo pipefail
ws=$(git rev-parse --show-toplevel)
mise trust "$ws/mise.toml"
mise install
