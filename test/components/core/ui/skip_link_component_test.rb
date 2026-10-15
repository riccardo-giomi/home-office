require "test_helper"

describe Core::UI::SkipLinkComponent do
  include ViewComponent::TestHelpers

  it "links to the target and moves focus there" do
    render_inline(Core::UI::SkipLinkComponent.new(target: "main-content"))
    assert_selector "a[href='#main-content'][data-action='focus-link#focus']", text: I18n.t("core.ui.skip_link")
  end

  it "passes extra attributes through, so a preview can focus it" do
    render_inline(Core::UI::SkipLinkComponent.new(target: "main-content", autofocus: true))
    assert_selector "a[autofocus]"
  end
end
