require "test_helper"

describe Core::UI::PanelComponent do
  include ViewComponent::TestHelpers

  it "is a section named by its own heading, around what it is given" do
    render_inline(Core::UI::PanelComponent.new(title: "Add a link", id: "picker")) { "Inside" }
    assert_selector "section#picker[aria-labelledby=picker-title] h3#picker-title", text: "Add a link"
    assert_selector "section#picker", text: "Inside"
  end

  it "carries the data attributes it is given" do
    render_inline(Core::UI::PanelComponent.new(title: "Add a link", id: "picker", data: {controller: "scroll-into-view"})) { "Inside" }
    assert_selector "section#picker[data-controller=scroll-into-view]"
  end
end
