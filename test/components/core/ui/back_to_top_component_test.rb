require "test_helper"

describe Core::UI::BackToTopComponent do
  include ViewComponent::TestHelpers

  it "is a named button that waits for the page to be scrolled, out of sight and of the tab order until then" do
    render_inline(Core::UI::BackToTopComponent.new)
    assert_selector "button[type=button][data-controller=back-to-top][data-action='back-to-top#go'].invisible", visible: :all
    assert_selector "button .sr-only", text: I18n.t("core.ui.back_to_top.label"), visible: :all
    assert_selector "button svg[aria-hidden=true]", visible: :all
    assert_no_selector "button[href]", visible: :all
  end

  it "is a square button, large enough to touch" do
    render_inline(Core::UI::BackToTopComponent.new)
    assert_selector "button.btn.btn-ghost.btn-square", visible: :all
  end

  it "can be shown at rest for a preview, without the script that would hide it again" do
    render_inline(Core::UI::BackToTopComponent.new(shown: true))
    assert_selector "button:not(.invisible):not([data-controller])"
  end
end
