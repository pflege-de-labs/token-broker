# Agent workspace for token-broker: GitHub access only through agent tokens from the broker.
# See docs/containers.md.
FROM mcr.microsoft.com/devcontainers/base:bookworm@sha256:755dde28df2490bf704d449be4b15b18fa62935dfcad4dfe26f996866e788f44

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor -o /usr/share/keyrings/mise.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/mise.gpg] https://mise.jdx.dev/deb stable main" > /etc/apt/sources.list.d/mise.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh mise ipset dnsmasq-base \
 && rm -rf /var/lib/apt/lists/*

# The empty value drops helpers inherited for github.com; useHttpPath tells the helper which repo.
RUN git config --system credential.https://github.com.helper '' \
 && git config --system --add credential.https://github.com.helper '!agent-token-git-credential' \
 && git config --system credential.https://github.com.useHttpPath true \
 && git config --system url.https://github.com/.insteadOf git@github.com: \
 && git config --system --add url.https://github.com/.insteadOf ssh://git@github.com/

# Root-owned in /usr/local/bin, ahead of /usr/bin/gh: agent-gh is installed as gh and finds the real one.
# shortcut: scripts fetched at a pinned commit; switch to the agent-token feature once it is published.
ARG AGENT_TOKEN_REF=9c3ea39799ee8eddbd0a2d4252c32883a385ef63
RUN base=https://raw.githubusercontent.com/pflege-de-labs/devcontainer-features/$AGENT_TOKEN_REF/src/agent-token/bin \
 && for f in agent-token agent-token-git-credential agent-github-mcp; do curl -fsSL "$base/$f" -o /usr/local/bin/$f; done \
 && curl -fsSL "$base/agent-gh" -o /usr/local/bin/gh \
 && chmod 755 /usr/local/bin/agent-token /usr/local/bin/agent-token-git-credential /usr/local/bin/agent-github-mcp /usr/local/bin/gh

# Managed settings: applies to every Claude Code session here and cannot be overridden per user.
COPY managed-settings.json /etc/claude-code/managed-settings.json

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
