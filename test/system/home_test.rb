require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  it "shows the home page without axe violations" do
    visit root_path
    assert_selector "h1", text: I18n.t("home.show.title")
    assert_accessible
  end
end
