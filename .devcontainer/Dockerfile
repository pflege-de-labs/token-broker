# Agent workspace for token-broker: GitHub access only through agent tokens from the broker.
# See docs/containers.md.
FROM mcr.microsoft.com/devcontainers/base:bookworm@sha256:755dde28df2490bf704d449be4b15b18fa62935dfcad4dfe26f996866e788f44

# gh, the agent-token scripts and their git config come from the agent-token feature (devcontainer.json).
RUN curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor -o /usr/share/keyrings/mise.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/mise.gpg] https://mise.jdx.dev/deb stable main" > /etc/apt/sources.list.d/mise.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends mise ipset dnsmasq-base \
 && rm -rf /var/lib/apt/lists/*

# Managed settings: applies to every Claude Code session here and cannot be overridden per user.
COPY managed-settings.json /etc/claude-code/managed-settings.json
# Managed memory: tells every Claude Code session here to commit with agent-commit.
COPY managed-CLAUDE.md /etc/claude-code/CLAUDE.md

# Root-owned copies, not links into the workspace: the agent can edit the workspace.
COPY allowed-domains /etc/agent-firewall/domains
COPY --chmod=755 init-firewall.sh /usr/local/bin/init-firewall.sh
# The base image grants vscode all of sudo, which would let the agent flush the firewall.
RUN grep -l 'NOPASSWD' /etc/sudoers.d/* | xargs rm \
 && echo 'vscode ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh ""' > /etc/sudoers.d/firewall \
 && chmod 440 /etc/sudoers.d/firewall

USER vscode
# Mount points exist before the volumes, so fresh volumes are owned by vscode, not root.
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && mkdir -p ~/.cache/agent-token ~/.local/share/mise ~/.claude
# Shims instead of shell activation, so non-interactive shells (Claude's, gopls) find the tools.
ENV PATH=/home/vscode/.local/share/mise/shims:/home/vscode/.local/bin:$PATH
