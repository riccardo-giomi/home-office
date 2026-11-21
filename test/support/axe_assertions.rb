require "axe/api"
require "axe/core"

module AxeAssertions
  # Axe::API::A11yCheck does not load with RubyGems 4 (it passes
  # Gem::Deprecate#deprecate two arguments, not four), so call the core
  # directly.
  def assert_accessible(page = self.page, within: nil)
    wait_for_transitions
    run = Axe::API::Run.new
    run = run.within(within) if within
    result = Axe::Core.new(page).call(run)
    assert result.passed?, result.failure_message
  end

  # If axe measures the color contrast while a dialog is fading in, it sees
  # half-faded colors and fails, so we wait for those transitions to end. This
  # is more likely on slower machines.
  #
  # Only CSSTransition is waited for, not CSSAnimation: daisyUI puts a
  # scroll-driven CSSAnimation on the page that never ends, so waiting for it
  # would never finish.
  def wait_for_transitions
    page.document.synchronize do
      running = evaluate_script("document.getAnimations().filter((a) => a instanceof CSSTransition && a.playState === 'running').length")
      raise Capybara::ExpectationNotMet, "#{running} transition(s) still running" if running.positive?
    end
  end
end
