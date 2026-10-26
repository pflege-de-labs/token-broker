# 5. Toolchains per repository via mise

- Status: accepted
- Date: 2026-10-26

## Context

Agents run in containers (`agent-run`, devcontainers) and work on repositories that need
different tools at different versions: Go, Terraform, Helm, linters. Baking them into the image
makes it large, couples every repo to one set of versions and needs a rebuild per update.

## Decision

The image holds only tools every repository needs, plus mise. Each repository pins its
toolchain in `mise.toml` (or `.tool-versions`); the container runs `mise install` at start and
puts mise shims on `PATH`. Installs and caches live in named volumes.

## Alternatives

- **All tools in the image:** one version per tool for every repo, large image, frequent
  rebuilds.
- **One image per repository:** exact versions, but an image to build and maintain per repo.
- **Devcontainer features:** devcontainers only; `agent-run` would need its own mechanism.

## Consequences

- Repositories without a mise config get no toolchain; adding one is the fix.
- The first session per tool version downloads it; Renovate's mise manager updates the pins.
- mise runs only the config of the mounted checkout (`MISE_TRUSTED_CONFIG_PATHS`).
