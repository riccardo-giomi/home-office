require "test_helper"

describe Core::UI::ThemeSwitchComponent do
  include ViewComponent::TestHelpers

  it "is a labeled switch bound to the controller and the endpoint" do
    render_inline(Core::UI::ThemeSwitchComponent.new(url: "/theme"))
    assert_selector "button[type=button][role=switch][data-controller=theme-switch][data-theme-switch-url-value='/theme']"
    assert_selector "button .sr-only", text: I18n.t("core.ui.theme_switch.label")
    assert_selector "button svg[aria-hidden=true]", count: 2, visible: :all
  end
end
