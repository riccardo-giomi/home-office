require "test_helper"

describe Core::UI::IconComponent do
  include ViewComponent::TestHelpers

  it "is always decorative" do
    render_inline(Core::UI::IconComponent.new(name: :home))
    assert_selector "svg[aria-hidden=true] path[d]"
  end

  it "has a path for every name it is asked for" do
    %i[home cog users swatch sun moon bars x_mark check warning checklist].each { |name| render_inline(Core::UI::IconComponent.new(name:)) }
    assert_raises(KeyError) { render_inline(Core::UI::IconComponent.new(name: :nope)) }
  end

  it "takes extra classes" do
    render_inline(Core::UI::IconComponent.new(name: :sun, class: "size-6"))
    assert_selector "svg.size-6"
  end
end
