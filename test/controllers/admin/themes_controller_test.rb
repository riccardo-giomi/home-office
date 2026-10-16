require "test_helper"

class Admin::ThemesControllerTest < ActionDispatch::IntegrationTest
  def shown_previews = ViewComponent::Preview.all.reject { |preview| preview.try(:page_level?) }

  it "sends visitors to sign in and keeps members out" do
    get admin_theme_path
    assert_redirected_to new_session_path
    sign_in_as users(:member)
    get admin_theme_path
    assert_redirected_to root_path
  end

  %w[light dark].each do |theme|
    it "renders the page in the #{theme} theme the user chose" do
      users(:admin).update!(theme:)
      sign_in_as users(:admin)
      get admin_theme_path
      assert_select "html[data-theme=#{theme}]"
    end
  end

  it "has the shell once: one header, one sidebar, one main, and the entry in the navigation for admins only" do
    sign_in_as users(:admin)
    get admin_theme_path
    assert_select "header", 1
    assert_select "nav#sidebar", 1
    assert_select "main", 1
    assert_select "nav a[href='#{admin_theme_path}']", text: I18n.t("core.nav.theme")
    sign_in_as users(:member)
    get root_path
    assert_select "nav a[href='#{admin_theme_path}']", 0
  end

  it "renders every example of every preview that can appear more than once" do
    sign_in_as users(:admin)
    get admin_theme_path
    assert_response :success
    assert_operator shown_previews.size, :>=, 8
    shown_previews.each do |preview|
      preview.examples.each do |example|
        assert_select "section[data-preview='#{preview.preview_name}'] [data-example='#{example}']", 1, "#{preview.name}##{example} is missing"
      end
    end
  end

  it "leaves out the components that exist once per page" do
    sign_in_as users(:admin)
    get admin_theme_path
    ViewComponent::Preview.all.select { |preview| preview.try(:page_level?) }.each do |preview|
      assert_select "section[data-preview='#{preview.preview_name}']", 0
    end
  end

  it "never repeats an element id, so no label can point at another example's field" do
    sign_in_as users(:admin)
    get admin_theme_path
    ids = css_select("[id]").map { it["id"] }
    _(ids.tally.select { |_, count| count > 1 }.keys).must_be_empty
  end

  it "shows the color tokens and the type scale" do
    sign_in_as users(:admin)
    get admin_theme_path
    assert_select "[data-tokens] [data-token=primary]"
    assert_select "[data-typography]"
  end
end
