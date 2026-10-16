require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AxeAssertions
  include LayoutAssertions
  include CspAssertions

  # Headless Chrome has no pointer that can hover, which switches every hover: style off; say it has a mouse
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
    options.add_argument("--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4")
  end

  # A test that resizes the window must not leave the next one narrow
  setup do
    page.current_window.resize_to(1400, 1400)
    record_csp_violations
  end

  # Before Capybara resets the session: afterwards the page is about:blank and cannot be asked
  def before_teardown
    assert_no_csp_violations
  ensure
    super
  end

  # 320 px is the reflow width of WCAG 1.4.10
  def small_screen(&block)
    page.driver.browser.manage.window.resize_to(320, 900)
    block.call
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  def sign_in_through_form(user, password: TEST_PASSWORD)
    visit new_session_path
    fill_in I18n.t("sessions.new.email_address"), with: user.email_address
    fill_in I18n.t("sessions.new.password"), with: password
    click_button I18n.t("sessions.new.submit")
    assert_selector "h1", text: I18n.t("home.show.title")
  end
end
