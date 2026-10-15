require "test_helper"

describe Core::UI::IconGalleryComponent do
  include ViewComponent::TestHelpers

  it "shows every icon by name, at its normal size and larger, so they can be compared" do
    render_inline(Core::UI::IconGalleryComponent.new)
    names = Core::UI::IconComponent::PATHS.keys
    assert_selector "ul li", count: names.size
    names.each { |name| assert_selector "li", text: name.to_s }
    assert_selector "li svg.size-5", count: names.size
    assert_selector "li svg.size-10", count: names.size
  end

  it "is the only example of the icon preview, so a new icon needs no preview change" do
    _(Core::UI::IconComponentPreview.examples).must_equal ["all"]
  end
end
