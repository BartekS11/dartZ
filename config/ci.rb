# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Tests: Smoke", "bin/rails test test/smoke"
  step "Tests: Pure Ruby core", %q(ruby -Ilib -e 'Dir["test/lib/darts/core/**/*_test.rb"].sort.each { |file| require "./#{file}" }')
  rails_test_command = if ENV["RUN_E2E"] == "true"
    "bin/rails test test/controllers test/integration test/jobs test/lib test/models test/performance test/presenters test/services test/smoke"
  else
    "bin/rails test"
  end
  step "Tests: Rails", rails_test_command

  if ENV["RUN_E2E"] == "true"
    step "Tests: E2E integration (Testcontainers PostgreSQL)", "bin/rails test test/e2e"
    step "Tests: E2E browser/system (Testcontainers PostgreSQL)", "bin/rails test test/system"
  end

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
