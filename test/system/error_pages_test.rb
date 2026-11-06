require "application_system_test_case"

# The static pages in public/, as a browser meets them: both colour schemes, a phone's width
class ErrorPagesTest < ApplicationSystemTestCase
  PAGES = %w[400.html 404.html 406-unsupported-browser.html 422.html 500.html].freeze

  def prefer_scheme(scheme)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [{name: "prefers-color-scheme", value: scheme}])
  end

  after { prefer_scheme("light") }

  %w[light dark].each do |scheme|
    PAGES.each do |file|
      it "shows #{file} to someone who prefers #{scheme}, with no accessibility violations, also on a phone" do
        prefer_scheme(scheme)
        visit "/#{file}"
        assert_selector "h1"
        assert_accessible
        small_screen { assert_fits_small_screen }
      end
    end
  end

  it "goes back to the app from the link" do
    visit "/404.html"
    click_link "Back to Home Office"
    assert_current_path new_session_path
  end

  it "is usable at 200% zoom" do
    visit "/500.html"
    page.driver.browser.execute_cdp("Emulation.setPageScaleFactor", pageScaleFactor: 2)
    assert_selector "a", text: "Back to Home Office"
  end
end
