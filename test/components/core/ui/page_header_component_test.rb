require "test_helper"

describe Core::UI::PageHeaderComponent do
  include ViewComponent::TestHelpers

  it "is the page's heading with the way back right under it" do
    render_inline(Core::UI::PageHeaderComponent.new(title: "Edit event: Dentist", back_href: "/planner/calendar", back_label: "Back to calendar"))
    assert_selector "h1", text: "Edit event: Dentist", count: 1
    assert_selector "a[href='/planner/calendar']", text: "Back to calendar"
    html = page.native.to_html
    assert_operator html.index("Edit event"), :<, html.index("Back to calendar")
  end

  it "has no back link when there is nowhere to go back to" do
    render_inline(Core::UI::PageHeaderComponent.new(title: "Home"))
    assert_selector "h1.mb-4", text: "Home"
    assert_no_selector "a"
    assert_no_selector "p"
  end

  it "lets a long title wrap instead of overflowing" do
    render_inline(Core::UI::PageHeaderComponent.new(title: "x" * 300))
    assert_selector "h1.wrap-anywhere"
  end

  it "keeps the back link at least 24 px tall, away from the buttons below" do
    render_inline(Core::UI::PageHeaderComponent.new(title: "T", back_href: "/", back_label: "Back"))
    assert_selector "a.min-h-6"
    assert_selector "p.mb-6"
  end

  it "has an id only when it is given one: the heading a dialog is named by" do
    render_inline(Core::UI::PageHeaderComponent.new(title: "Plain"))
    assert_no_selector "h1[id]"
    render_inline(Core::UI::PageHeaderComponent.new(title: "In a dialog", id: "dialog-title", back_href: "/", back_label: "Back"))
    assert_selector "h1#dialog-title"
  end
end
