require "axe/api"
require "axe/core"

module AxeAssertions
  # Axe::API::A11yCheck raises on Ruby 4.0.5, so call the core directly.
  def assert_accessible(page = self.page)
    result = Axe::Core.new(page).call(Axe::API::Run.new)
    assert result.passed?, result.failure_message
  end
end
