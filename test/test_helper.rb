ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/query_counting"
require_relative "test_helpers/catch_up_mode"

ENV["HOME_OFFICE_CATCH_UP"] = "off"

Dir[Rails.root.join("test/support/**/*.rb")].each { |file| require file }

TEST_PASSWORD = "this is a long password, isn't it?".freeze

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # The rate limiter needs a real cache store, which must not keep counts between tests
    setup { Rails.cache.clear }

    include QueryCounting
    include CatchUpMode

    # Add more helper methods to be used by all tests here...
  end
end
