require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  before { users(:member).update!(locale: "en") }

  it "sends anonymous visitors to sign in" do
    get settings_path
    assert_redirected_to new_session_path
  end

  it "shows a card for Preferences" do
    sign_in_as users(:member)
    get settings_path
    assert_response :success
    assert_select "title", "Settings | Home Office"
    assert_select "h1", "Settings"
    assert_select "ul[aria-label='Settings'] > li", 1
    assert_select "a[href='#{edit_preferences_path}']", text: /Preferences/
  end

  it "has no link back home, the sidebar is the way" do
    sign_in_as users(:member)
    get settings_path
    assert_select "main a", text: /Back/, count: 0
  end
end
