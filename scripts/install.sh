#!/usr/bin/env bash
# Installs the token-broker client scripts from a GitHub release, checked against its checksums.txt.
# Usage: curl -fsSL https://raw.githubusercontent.com/pflege-de-labs/token-broker/main/scripts/install.sh | bash [-s -- --version vX.Y.Z]
# PREFIX (default ~/.local) chooses the install directory $PREFIX/bin.
set -euo pipefail

# A function, so a download cut off by the network runs nothing.
main() {
  local repo=pflege-de-labs/token-broker tag='' bindir=${PREFIX:-$HOME/.local}/bin
  # Tests point this at a local directory laid out like the release downloads.
  local base=${TOKEN_BROKER_RELEASE_BASE:-https://github.com/$repo/releases/download}
  while (($#)); do
    case $1 in
      --version) tag=${2:?--version needs a tag, e.g. v0.6.0}; shift 2 ;;
      *) die "unknown argument $1" ;;
    esac
  done
  for cmd in curl jq tar; do command -v "$cmd" >/dev/null || die "$cmd is required"; done
  for cmd in git gh; do command -v "$cmd" >/dev/null || echo "install.sh: warning: $cmd is missing; agent-gh and agent-commit need it" >&2; done

  if [[ -z $tag ]]; then
    # Not releases/latest: that can be a chart release (token-broker-x.y.z), which has no client tarball.
    tag=$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=100" |
      jq -r '[.[] | select(.prerelease or .draft | not) | .tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))][0] // empty')
    [[ -n $tag ]] || die "found no client release of $repo"
  fi
  [[ $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die "not a release tag: $tag"

  local file=agent-token-${tag#v}.tar.gz tmp want got
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064 # expand now: tmp is local and gone when the trap runs
  trap "rm -rf '$tmp'" EXIT
  curl -fsSL -o "$tmp/$file" "$base/$tag/$file" || die "download of $file failed"
  curl -fsSL -o "$tmp/checksums.txt" "$base/$tag/checksums.txt" || die "download of checksums.txt failed"
  want=$(awk -v f="$file" '$2 == f { print $1 }' "$tmp/checksums.txt")
  if command -v sha256sum >/dev/null; then got=$(sha256sum "$tmp/$file"); else got=$(shasum -a 256 "$tmp/$file"); fi
  [[ -n $want && ${got%% *} == "$want" ]] || die "checksum mismatch for $file"

  tar -xzf "$tmp/$file" -C "$tmp"
  mkdir -p "$bindir"
  # agent-gh keeps its name: installed as gh it would also catch the user's own gh calls.
  for f in agent-token agent-token-git-credential agent-gh agent-github-mcp agent-commit; do
    install -m 755 "$tmp/bin/$f" "$bindir/$f"
  done
  echo "Installed agent-token $tag into $bindir"
  case ":$PATH:" in *":$bindir:"*) ;; *) echo "Add $bindir to your PATH." ;; esac
  cat <<'EOF'

Next, once per 8 hours:
  export TOKEN_BROKER_URL=https://<broker>   # internal broker URL of your deployment
  agent-token --login

With Claude Code, install the plugin instead; it brings the same scripts and finds the broker URL:
  claude plugin marketplace add pflege-de-labs/token-broker
  claude plugin install agent-token@pflege-de-token-broker
EOF
}

die() {
  echo "install.sh: $*" >&2
  exit 1
}

main "$@"
