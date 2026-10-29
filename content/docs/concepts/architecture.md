---
title: Architecture
weight: 1
---

Coding agents need to push code and open pull requests. Giving them a developer's credentials
makes every agent action look like the developer's, and a prompt injection then holds everything
the developer can do. Token Broker gives the agent its own GitHub identity instead: a GitHub App.
Its commits and pull requests show up as `<app>[bot]` and need a human review.

## One key, one place

An app can mint installation tokens only with its private key. The key lives in the broker alone.
Agents, containers and workstations ask the broker for a token and never see the key.

## Two auth paths

| Caller | Proves identity with | Endpoint |
| --- | --- | --- |
| Developer (local agent) | user token of a permission-less login app, via device flow | `POST /token` |
| GitHub Actions workflow | the workflow's OIDC token | `POST /token/actions` (or `/token`) |

* **Developer.** `agent-token --login` runs GitHub's device flow with the **login app**, an app
  with no permissions at all. It only proves who the developer is. The login token lives 8 hours
  in the developer's cache. The broker asks GitHub whether that user has write access to the
  requested repository and refuses otherwise: a developer can hand the agent only repositories
  they could push to themselves.
* **Workflow.** The workflow requests an OIDC token with the audience the broker expects and
  sends it to the broker. The broker verifies it against GitHub's issuer. A workflow gets a token
  only for the repository it runs in, optionally limited to certain refs and workflows.
  `/token/actions` accepts nothing but these tokens, so a public route can forward it while
  everything else stays internal.

## What the token is

In both cases the broker then:

1. checks that the repository belongs to one of the configured organizations;
2. signs an app JWT with the private key and looks up the app's installation on the repository,
   refusing if the app is not installed there;
3. mints an installation token for that one repository, with the configured permissions
   (default: contents, pull requests and issues write, metadata read).

The token lives one hour. Clients fetch tokens on demand, per repository, at the moment git, `gh`
or the GitHub MCP server need one, and cache them. Every issued or denied token is logged: who,
which repository, why.

## Parts

* **Broker:** a small stateless Go service, run as a Helm chart with two replicas. It has no
  database and never calls the Kubernetes API.
* **Client scripts:** `agent-token` and the helpers built on it. See
  [Client commands](../../reference/client-cli/).
* **Claude Code plugin, Dev Container Feature and `agent-run`:** three ways to put the client
  into the agent's environment. See [Getting started](../../getting-started/).

Setup details: [Set up the GitHub Apps](../../guides/github-apps/). Endpoints and errors:
[Endpoints](../../reference/endpoints/).
