require "test_helper"

describe Core::UI::BadgeComponent do
  include ViewComponent::TestHelpers

  def badge(count, label: "#{count} tasks") = render_inline(Core::UI::BadgeComponent.new(count:, label:))

  it "shows the number, with a label for screen readers" do
    badge(3)
    assert_selector "span.badge", text: /3/
    assert_selector "span[aria-hidden=true]", text: "3"
    assert_selector ".sr-only", text: "3 tasks"
  end

  it "shows nothing at zero, for nil and for a negative number" do
    [0, nil, -1].each do |count|
      badge(count)
      assert_no_selector "span"
    end
  end

  it "stops counting at 99" do
    badge(99)
    assert_selector "span[aria-hidden=true]", text: "99"
    badge(100)
    assert_selector "span[aria-hidden=true]", text: "99+"
    assert_selector ".sr-only", text: "100 tasks"
  end
end
