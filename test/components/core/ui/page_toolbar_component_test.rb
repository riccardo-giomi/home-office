require "test_helper"

describe Core::UI::PageToolbarComponent do
  include ViewComponent::TestHelpers

  def toolbar
    render_inline(Core::UI::PageToolbarComponent.new) do |component|
      component.with_leading { "<a class='btn' href='/new'>New event</a>".html_safe }
      component.with_trailing { "<a class='btn' href='/list'>Show as list</a>".html_safe }
    end
  end

  it "puts the main action at the start and the way to another view of the same thing at the other end" do
    toolbar
    assert_selector "div.flex.justify-between"
    html = page.native.to_html
    assert_operator html.index("New event"), :<, html.index("Show as list")
  end

  it "wraps instead of overflowing, with room between the two lines when it does" do
    toolbar
    assert_selector "div.flex-wrap.gap-2"
  end

  it "renders with only one of the two" do
    render_inline(Core::UI::PageToolbarComponent.new) { |component| component.with_leading { "<a href='/new'>New</a>".html_safe } }
    assert_selector "a", text: "New", count: 1
  end

  it "is a plain group of controls, not a landmark of its own" do
    toolbar
    assert_no_selector "nav, [role=toolbar]"
  end
end
