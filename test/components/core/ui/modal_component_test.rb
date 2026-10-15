require "test_helper"

describe Core::UI::ModalComponent do
  include ViewComponent::TestHelpers

  it "renders a dialog named by its heading, a trigger, the body and a close button" do
    render_inline(Core::UI::ModalComponent.new(id: "demo", title: "Delete?", trigger: "Delete")) { "Are you sure?" }
    assert_selector "[data-controller=modal] button[aria-haspopup=dialog]", text: "Delete"
    assert_selector "dialog#demo[aria-labelledby=demo-title] h2#demo-title", text: "Delete?", visible: :all
    assert_selector "dialog#demo", text: "Are you sure?", visible: :all
    assert_selector "dialog#demo form[method=dialog] button", text: I18n.t("core.ui.modal.close"), visible: :all
  end

  it "closes itself before Turbo caches the page" do
    render_inline(Core::UI::ModalComponent.new(id: "demo", title: "T", trigger: "Open")) { "x" }
    assert_selector "[data-controller=modal][data-action~='turbo:before-cache@document->modal#close']"
  end

  it "can draw its trigger as a dangerous action" do
    render_inline(Core::UI::ModalComponent.new(id: "demo", title: "Delete?", trigger: "Delete", trigger_variant: :danger)) { "Sure?" }
    assert_selector "[data-controller=modal] > button.btn-error[aria-haspopup=dialog]", text: "Delete"
  end

  it "can draw a small trigger" do
    render_inline(Core::UI::ModalComponent.new(id: "demo", title: "T", trigger: "Open", trigger_size: :xs)) { "x" }
    assert_selector "[data-controller=modal] > button.btn.btn-xs", text: "Open"
  end
end
