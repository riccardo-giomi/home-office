require "test_helper"

describe Core::UI::TabsComponent do
  include ViewComponent::TestHelpers

  def tabs(**options)
    items = [["Month", "/month?date=2026-10-07", false], ["Week", "/week?date=2026-10-07", true], ["Day", "/day", false]]
    Core::UI::TabsComponent.new(items:, **options)
  end

  it "is a list of links, each a button, whose address says where it goes" do
    render_inline(tabs)
    assert_selector "ul li a.btn", count: 3
    assert_selector "a[href='/month?date=2026-10-07']", text: "Month"
  end

  it "marks the current tab with aria-current, a check and the one solid button" do
    render_inline(tabs)
    assert_selector "a[aria-current=true]", count: 1
    assert_selector "a.btn-neutral[aria-current=true][href='/week?date=2026-10-07']", text: "Week"
    assert_selector "a[aria-current=true] svg"
    assert_no_selector "a.btn-neutral:not([aria-current])"
  end

  it "marks nothing when no tab is current" do
    render_inline(Core::UI::TabsComponent.new(items: [["A", "/a", false], ["B", "/b", false]]))
    assert_no_selector "[aria-current]"
  end

  it "takes a label for the list, for use outside a labeled navigation" do
    render_inline(tabs(label: "Views"))
    assert_selector "ul[aria-label='Views']"
  end

  it "stays a row of separate buttons that wraps instead of overflowing" do
    render_inline(tabs)
    assert_selector "ul.flex.flex-wrap.gap-2"
  end
end
