# Agent workspace for token-broker: GitHub access only through agent tokens from the broker.
# See docs/containers.md.
FROM mcr.microsoft.com/devcontainers/base:bookworm@sha256:755dde28df2490bf704d449be4b15b18fa62935dfcad4dfe26f996866e788f44

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor -o /usr/share/keyrings/mise.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/mise.gpg] https://mise.jdx.dev/deb stable main" > /etc/apt/sources.list.d/mise.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh mise \
 && rm -rf /var/lib/apt/lists/*

# The empty value drops helpers inherited for github.com; useHttpPath tells the helper which repo.
RUN git config --system credential.https://github.com.helper '' \
 && git config --system --add credential.https://github.com.helper '!agent-token-git-credential' \
 && git config --system credential.https://github.com.useHttpPath true \
 && git config --system url.https://github.com/.insteadOf git@github.com: \
 && git config --system --add url.https://github.com/.insteadOf ssh://git@github.com/

# Managed settings: applies to every Claude Code session here and cannot be overridden per user.
COPY managed-settings.json /etc/claude-code/managed-settings.json

USER vscode
# Mount points exist before the volumes, so fresh volumes are owned by vscode, not root.
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && mkdir -p ~/.cache/agent-token ~/.local/share/mise
# Shims instead of shell activation, so non-interactive shells (Claude's, gopls) find the tools.
ENV PATH=/home/vscode/.local/share/mise/shims:/home/vscode/.local/bin:$PATH
