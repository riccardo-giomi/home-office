require "test_helper"

class ThemesControllerTest < ActionDispatch::IntegrationTest
  it "remembers a visitor's choice in a cookie only" do
    assert_no_changes -> { User.pluck(:theme) } do
      patch theme_path, params: {theme: "dark"}
    end
    assert_response :no_content
    assert_equal "dark", cookies[:theme]
  end

  it "stores a signed-in user's choice and mirrors it" do
    sign_in_as users(:member)
    patch theme_path, params: {theme: "dark"}
    assert_response :no_content
    assert_equal "dark", users(:member).reload.theme
    assert_equal "dark", cookies[:theme]
  end

  it "rejects anything but light and dark and stores nothing" do
    sign_in_as users(:member)
    ["blue", "", "Dark", "dark;x"].each do |bad|
      patch theme_path, params: {theme: bad}
      assert_response :unprocessable_content
    end
    patch theme_path
    assert_response :unprocessable_content
    assert_nil users(:member).reload.theme
  end

  it "renders the stored theme on the page and the cookie goes away on Automatic" do
    users(:member).update!(theme: "dark")
    sign_in_as users(:member)
    get root_path
    assert_select "html[data-theme=dark]"
    assert_equal "dark", cookies[:theme]
    users(:member).update!(theme: nil)
    get root_path
    assert_select "html[data-theme]", count: 0
    assert cookies[:theme].blank?
  end

  it "ignores a hostile cookie on the sign-in page" do
    cookies[:theme] = %("><script>alert(1)</script>)
    get new_session_path
    assert_select "html[data-theme]", count: 0
    assert_select "script", text: /alert/, count: 0
  end

  it "renders a visitor's cookie on the sign-in page" do
    cookies[:theme] = "dark"
    get new_session_path
    assert_select "html[data-theme=dark]"
  end
end
