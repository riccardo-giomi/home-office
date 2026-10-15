require "test_helper"

describe Core::UI::NoscriptNoticeComponent do
  include ViewComponent::TestHelpers

  it "is hidden unless scripting is off, with a heading and text" do
    render_inline(Core::UI::NoscriptNoticeComponent.new)
    assert_selector "div.hidden.noscript\\:flex h1", text: I18n.t("core.ui.noscript.title"), visible: :all
    assert_text I18n.t("core.ui.noscript.body")
  end

  it "can be shown as it looks without JavaScript, for previews" do
    render_inline(Core::UI::NoscriptNoticeComponent.new(shown: true))
    assert_selector "div.flex h1", text: I18n.t("core.ui.noscript.title")
    assert_no_selector "div.hidden", visible: :all
  end
end
