# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Tests: Smoke", "bin/rails test test/smoke"
  step "Tests: Pure Ruby core", %q(ruby -Ilib -e 'Dir["test/lib/darts/core/**/*_test.rb"].sort.each { |file| require "./#{file}" }')
  step "Tests: Rails", "bin/rails test"

  step "Style: Ruby", "bin/rubocop"
  step "Linting: Ruby", "bin/rubocop -A"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"


  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
