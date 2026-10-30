# The release workflow's formula job bumps url and sha256 (ADR 15).
class AgentToken < Formula
  desc "Short-lived GitHub App tokens for coding agents, from token-broker"
  homepage "https://pflege-de-labs.github.io/token-broker/"
  url "https://github.com/pflege-de-labs/token-broker/releases/download/v0.7.0/agent-token-0.7.0.tar.gz"
  sha256 "2ce3a9e1ffc779e0d8e7baa1360cd4e6baec9d60be6a25d68db0026a535cd3ef"

  depends_on "gh"
  depends_on "jq"

  def install
    # The tarball holds only bin/, so Homebrew has already changed into it.
    bin.install Dir["*"]
  end

  def caveats
    <<~EOS
      With Claude Code, install the plugin as well; it finds the broker URL itself:
        claude plugin marketplace add pflege-de-labs/token-broker
        claude plugin install agent-token@pflege-de-token-broker

      Without the plugin, set TOKEN_BROKER_URL and log in once per 8 hours:
        agent-token --login
    EOS
  end

  test do
    # Runs before any network access: without a broker URL agent-token stops at once.
    assert_match "TOKEN_BROKER_URL", shell_output("#{bin}/agent-token org/repo 2>&1", 1)
  end
end
