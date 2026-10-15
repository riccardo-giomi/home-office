require "test_helper"

# Lookbook and /rails/view_components render previews in their own layout: the application
# layout needs a request, a user and preferences that a preview does not have.
class ComponentPreviewsTest < ActionDispatch::IntegrationTest
  it "renders every preview example on its own" do
    ViewComponent::Preview.all.each do |preview|
      preview.examples.each do |example|
        get "/rails/view_components/#{preview.preview_name}/#{example}"
        assert_response :success, "#{preview.name}##{example}"
      end
    end
  end

  it "has the stylesheet and scripts but no application shell" do
    get "/rails/view_components/core/ui/button_component/primary"
    assert_select "link[rel=stylesheet]"
    assert_select "script[type=importmap]"
    assert_select "header, nav, main, #announcements", count: 0
  end

  it "shows a preview in the theme Lookbook's display option asks for, and in the browser's own by default" do
    get "/rails/view_components/core/ui/button_component/primary"
    assert_select "html[data-theme]", count: 0
    get "/rails/view_components/core/ui/button_component/primary", params: {lookbook: {display: {theme: "dark"}}}
    assert_select "html[data-theme=dark]"
    get "/rails/view_components/core/ui/button_component/primary", params: {lookbook: {display: {theme: "light"}}}
    assert_select "html[data-theme=light]"
  end

  it "ignores a theme it does not know" do
    get "/rails/view_components/core/ui/button_component/primary", params: {lookbook: {display: {theme: "\"><script>"}}}
    assert_select "html[data-theme]", count: 0
  end
end
