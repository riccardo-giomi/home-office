require "test_helper"

describe Core::UI::FormActionsComponent do
  include ViewComponent::TestHelpers

  def actions(**slots)
    render_inline(Core::UI::FormActionsComponent.new) do |component|
      component.with_primary { "<button class='btn'>Save</button>".html_safe }
      component.with_danger { "<div><button class='btn btn-error'>Delete</button></div>".html_safe } if slots[:danger]
    end
  end

  it "puts Save and the dangerous action on one line at opposite ends from sm up" do
    actions(danger: true)
    assert_selector "div.sm\\:flex-row.sm\\:justify-between"
    html = page.native.to_html
    assert_operator html.index("Save"), :<, html.index("Delete")
  end

  it "stacks them on a phone with plenty of room between, both stretched" do
    actions(danger: true)
    assert_selector "div.flex-col.gap-8"
    assert_selector "div[class*='[&>.btn]:w-full'][class*='[&>div>.btn]:w-full']"
  end

  it "renders just the primary action when there is no dangerous one (a new record)" do
    actions
    assert_selector "button", text: "Save", count: 1
    assert_no_text "Delete"
  end
end
