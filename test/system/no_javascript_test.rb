require "application_system_test_case"

class NoJavascriptTest < ApplicationSystemTestCase
  # Its own driver name: Capybara keeps one browser session per name, so the shared :selenium one would leak
  Capybara.register_driver :headless_chrome_without_javascript do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_preference("profile.managed_default_content_settings.javascript", 2)
    Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
  end

  setup do
    Capybara.current_driver = :headless_chrome_without_javascript
  end

  it "shows only the notice on the sign-in page" do
    visit new_session_path
    assert_selector "h1", text: I18n.t("core.ui.noscript.title")
    assert_no_selector "main", visible: :visible
    assert_no_selector "form", visible: :visible
  end
end
