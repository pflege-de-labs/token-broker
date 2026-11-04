# token-broker

## Definition of done

An implementation (of a plan, feature or fix) is complete only when its documentation matches the
code. Check both places before claiming it is done:

- **This repository:** `README.md`, `docs/*.md`, a new or amended ADR in `docs/adr/` for every
  architectural decision, `client/README.md`, and the chart's `values.yaml` comments.
- **Docs site:** branch `pages` (Hugo, served at <https://pflege-de-labs.github.io/token-broker/>).
  Update user-visible changes there in a PR against `pages`, with the German page (`*.de.md`) in
  the same PR. Architecture pages live under `content/docs/concepts/`.

If no doc changes are needed, say so explicitly. Open the `pages` PR together with the code PR;
a code PR without it is not done.
