require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  it "serves the placeholder home page to a signed-in user" do
    sign_in_as users(:admin)
    get root_path
    assert_response :success
    assert_select "h1", text: I18n.t("home.show.title")
  end

  it "links to the preferences page" do
    sign_in_as users(:member)
    get root_path
    assert_select "a[href=?]", edit_preferences_path
  end

  it "sends an anonymous visitor to sign in" do
    get root_path
    assert_redirected_to new_session_path
  end
end
