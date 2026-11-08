require "application_system_test_case"

class ThemePageTest < ApplicationSystemTestCase
  before { sign_in_through_form users(:admin) }

  # The theme switch arrives with the page shell: until then the page is put in a theme by its attribute
  # No axe scan of the whole page: it only shows what the component previews show,
  # and it lists all of them, so a scan can exceed the driver's script timeout on a
  # slow machine. Axe checks each component on its own in component_previews_test.
  %w[light dark].each do |theme|
    it "renders the Theme page in the #{theme} theme" do
      visit admin_theme_path
      execute_script("document.documentElement.dataset.theme = '#{theme}'")
      assert_selector "[data-tokens]"
      assert_selector "h1"
    end
  end

  it "fits a 320 px screen" do
    small_screen do
      visit admin_theme_path
      assert_selector "[data-tokens]"
      assert_fits_small_screen
    end
  end
end
