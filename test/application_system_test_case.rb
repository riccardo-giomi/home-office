require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AxeAssertions
  include LayoutAssertions

  # Headless Chrome has no pointer that can hover, which switches every hover: style off; say it has a mouse
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
    options.add_argument("--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4")
  end

  # A test that resizes the window must not leave the next one narrow
  setup { page.current_window.resize_to(1400, 1400) }
end
