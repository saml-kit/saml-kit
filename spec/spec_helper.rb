require "bundler/setup"
require "saml/kit"
require "active_support/testing/time_helpers"
require "ffaker"
require "webmock/rspec"

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.after :each do
    travel_back
  end
end
