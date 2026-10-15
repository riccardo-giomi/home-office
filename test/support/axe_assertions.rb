require "axe/api"
require "axe/core"

module AxeAssertions
  # Axe::API::A11yCheck raises on Ruby 4.0.5, so call the core directly.
  # within: a selector, for what is on top of the page (an open modal dialog; the page behind it
  # is inert and dimmed by the backdrop, which axe would report as low contrast)
  def assert_accessible(page = self.page, within: nil)
    run = Axe::API::Run.new
    run = run.within(within) if within
    result = Axe::Core.new(page).call(run)
    assert result.passed?, result.failure_message
  end
end
