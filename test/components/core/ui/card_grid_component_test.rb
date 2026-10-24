require "test_helper"

describe Core::UI::CardGridComponent do
  include ViewComponent::TestHelpers

  it "is a list with a cell for each card" do
    render_inline(Core::UI::CardGridComponent.new(label: "Modules")) do |grid|
      grid.with_card { "One" }
      grid.with_card { "Two" }
    end
    assert_selector "ul[aria-label='Modules'] > li", count: 2
    assert_selector "ul > li", text: "Two"
  end

  it "draws nothing without cards" do
    render_inline(Core::UI::CardGridComponent.new(label: "Modules"))
    assert_no_selector "ul"
  end
end
