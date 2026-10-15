require "test_helper"

describe Core::UI::FlashComponent do
  include ViewComponent::TestHelpers

  it "renders a notice as a status with an icon and the text" do
    render_inline(Core::UI::FlashComponent.new(kind: "notice", message: "Saved"))
    assert_selector "[role=status]", text: "Saved"
    assert_selector "[role=status] svg[aria-hidden=true]"
  end

  it "is a soft, tinted alert, not a solid bar" do
    render_inline(Core::UI::FlashComponent.new(kind: "notice", message: "Saved"))
    assert_selector "[role=status].alert.alert-soft.alert-success"
    render_inline(Core::UI::FlashComponent.new(kind: "alert", message: "Nope"))
    assert_selector "[role=alert].alert.alert-soft.alert-error"
  end

  it "renders an alert as an alert with an icon and the text" do
    render_inline(Core::UI::FlashComponent.new(kind: :alert, message: "Nope"))
    assert_selector "[role=alert]", text: "Nope"
    assert_selector "[role=alert] svg[aria-hidden=true]"
  end

  it "renders nothing for an unknown kind or a blank message" do
    render_inline(Core::UI::FlashComponent.new(kind: "weird", message: "Hi"))
    assert_no_selector "div"
    render_inline(Core::UI::FlashComponent.new(kind: "notice", message: ""))
    assert_no_selector "div"
  end
end
