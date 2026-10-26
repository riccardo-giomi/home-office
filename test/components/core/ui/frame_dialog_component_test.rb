require "test_helper"

describe Core::UI::FrameDialogComponent do
  include ViewComponent::TestHelpers

  def dialog(**options) = render_inline(Core::UI::FrameDialogComponent.new(id: "event-dialog", frame_id: "event-dialog-frame", **options))

  it "is a native dialog named by the heading that arrives inside it, holding an empty turbo frame" do
    dialog
    assert_selector "dialog#event-dialog.modal[aria-labelledby=dialog-title]", visible: :all
    assert_selector "dialog turbo-frame#event-dialog-frame:empty", visible: :all
  end

  it "has a close button with a name, last in the order so the first field gets the focus when it opens" do
    dialog
    assert_selector "dialog form[method=dialog] button[aria-label='#{I18n.t("core.ui.modal.close")}']", visible: :all
    html = page.native.to_html
    assert_operator html.index("event-dialog-frame"), :<, html.index("aria-label=\"#{I18n.t("core.ui.modal.close")}\"")
  end

  it "draws the close button with a proper icon, big enough to hit" do
    dialog
    assert_selector "dialog button.btn-circle svg[aria-hidden=true]", visible: :all
  end

  it "wires the script: opens when the frame has loaded, empties it when closed, closes on the backdrop and before caching" do
    dialog
    assert_selector "[data-controller=frame-dialog]", visible: :all
    assert_selector "turbo-frame[data-action='turbo:frame-load->frame-dialog#open']", visible: :all
    assert_selector "dialog[data-action~='close->frame-dialog#emptied'][data-action~='click->frame-dialog#backdrop']", visible: :all
    assert_selector "[data-action~='turbo:before-cache@document->frame-dialog#beforeCache']", visible: :all
  end

  it "is kept as it is when the page behind refreshes, so a refresh cannot close it or empty it" do
    dialog
    assert_selector "div#event-dialog-host[data-turbo-permanent][data-controller=frame-dialog]", visible: :all
  end

  it "fills a phone, and is a box of its own from sm up" do
    dialog
    assert_selector "dialog .modal-box.h-full.w-full.max-w-none.sm\\:h-auto.sm\\:max-w-2xl", visible: :all
  end

  it "can be drawn open, for a preview" do
    dialog(open: true)
    assert_selector "dialog[open]"
  end
end
