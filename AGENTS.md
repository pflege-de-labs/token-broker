# Token Broker user documentation

This branch is the source of the Token Broker user documentation site,
<https://pflege-de-labs.github.io/token-broker/>. It holds no Go code. The application, its
architecture, [ADRs](https://github.com/pflege-de-labs/token-broker/tree/main/docs/adr) and
contribution rules live on `main`.

## Branches and versions

| Branch | Documents | Published at |
| --- | --- | --- |
| `pages` | unreleased `main` | `/token-broker/dev/` |
| `pages-vX.Y` | release `vX.Y.*` | `/token-broker/vX.Y/` |
| `gh-pages` | built output, written by CI only | — |

* A user-visible change on `main` gets a pull request here, against `pages`.
* A fix that also applies to a released version is cherry-picked onto its `pages-vX.Y`.
* Merge the docs for everything in a release before it is tagged: a stable `vX.Y.0` tag makes
  `main`'s release workflow create `pages-vX.Y` from `pages` and deploy it.
* A pull request is previewed at `/token-broker/pr-preview/pr-N/` and the bot comments the link.

## Layout

* `content/docs/` — the documentation in English (`name.md`) and German (`name.de.md`), sorted by
  [Diátaxis](https://diataxis.fr/):
  `getting-started/` (tutorials), `guides/` (how-to), `reference/`, `concepts/` (explanation).
* `layouts/` — overrides of the [Hextra](https://imfing.github.io/hextra/) theme. Keep them few;
  each is a copy that a theme update does not reach.
* `assets/js/versions.js` — fills the version menu and banner from `versions.json`.
* `i18n/` — labels of the version menu and banner, per language. `GLOSSARY.de.md` — the German
  terms.
* `scripts/check-translations.sh` — fails when a page lacks its counterpart in either language.
* `scripts/versions.sh` — writes `versions.json` and the root redirect from the `pages-v*`
  branches.

## Writing

The site is English and German. English is the source and is served at the version root; German
is served under `de/`.

* `docs-writer` (`.claude/agents/docs-writer.md`) writes and revises the English pages.
* `docs-translator` (`.claude/agents/docs-translator.md`) writes the German page for each of them
  and carries later English changes into it.

Use both, in that order, in the same pull request: a pull request that changes an English page
changes its German page too. Their rules apply to anyone writing here. Each docs pull request
links the pull request on `main` whose behaviour it documents, and that one links back; `main`'s
definition of done requires it.

## Definition of done

* `make build` passes: `--panicOnWarning` turns a broken `ref` or shortcode into a failure.
* `make lint` is clean: markdownlint with `main`'s rules, and every page in both languages.
* The German pages say what the English pages say, in the terms of `GLOSSARY.de.md`.
* Every flag, key, path and default on a page matches the code at the version the branch documents.
* Commits follow [Conventional Commits](https://www.conventionalcommits.org), usually `docs:`.

## Local preview

```bash
make serve          # http://localhost:1313/token-broker/dev/
```

Requires Hugo (version in `.github/workflows/docs-deploy.yml`) and Go for the theme module.
