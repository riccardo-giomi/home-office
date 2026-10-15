require "test_helper"

describe Core::UI::HeaderComponent do
  include ViewComponent::TestHelpers

  it "is the banner: menu button, app name, page name and the controls" do
    render_inline(Core::UI::HeaderComponent.new(page_title: "Preferences")) { "controls" }
    assert_selector "header button[aria-controls=sidebar][aria-expanded=false][data-sidebar-target=button]", visible: :all
    assert_selector "header button[aria-controls=sidebar] .sr-only", text: I18n.t("core.ui.header.menu"), visible: :all
    assert_text "#{I18n.t("core.app_name")} / Preferences"
    assert_text "controls"
  end

  it "shows only the app name on the home page" do
    render_inline(Core::UI::HeaderComponent.new(page_title: nil))
    assert_no_text "/"
  end

  it "leaves out the menu button for visitors" do
    render_inline(Core::UI::HeaderComponent.new(page_title: nil, menu: false))
    assert_no_selector "button", visible: :all
  end
end
