require "test_helper"

describe Core::UI::CardLinkComponent do
  include ViewComponent::TestHelpers

  def card(**options) = render_inline(Core::UI::CardLinkComponent.new(href: "/planner/trash", title: "Planner", caption: "In the trash:", lines: ["12 events", "3 tasks", "0 todos"], **options))

  it "is one link holding the title, the caption and every line as text" do
    card
    assert_selector "a[href='/planner/trash']", count: 1
    assert_selector "a", text: "Planner"
    assert_selector "a", text: "In the trash:"
    ["12 events", "3 tasks", "0 todos"].each { |line| assert_selector "a", text: line }
  end

  it "holds no other interactive element, which a link cannot contain" do
    card
    assert_no_selector "a a, a button, a input"
  end

  it "needs no caption" do
    render_inline(Core::UI::CardLinkComponent.new(href: "#", title: "Planner", lines: ["1 event"]))
    assert_selector "a", text: "Planner"
    assert_no_text "In the trash"
  end

  it "lets a very long word break instead of leaving the card" do
    card
    assert_selector "a span.wrap-anywhere", count: 5
  end
end
