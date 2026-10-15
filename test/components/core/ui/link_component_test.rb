require "test_helper"

describe Core::UI::LinkComponent do
  include ViewComponent::TestHelpers

  it "renders a link with the block content and a minimum target size" do
    render_inline(Core::UI::LinkComponent.new(href: "/somewhere")) { "Go" }
    assert_selector "a.link.min-h-6.min-w-6[href='/somewhere']", text: "Go"
  end

  it "passes extra attributes through" do
    render_inline(Core::UI::LinkComponent.new(href: "/x", data: {turbo: false})) { "Go" }
    assert_selector "a[data-turbo=false]"
  end
end
