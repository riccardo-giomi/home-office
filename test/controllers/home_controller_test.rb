require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  it "serves the placeholder home page" do
    get root_path
    assert_response :success
    assert_select "h1", text: I18n.t("home.show.title")
  end
end
