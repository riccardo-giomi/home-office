require "test_helper"

describe Core::UI::LiveRegionComponent do
  include ViewComponent::TestHelpers

  it "is one polite status region that survives Turbo visits" do
    render_inline(Core::UI::LiveRegionComponent.new)
    assert_selector "#announcements[role=status][aria-live=polite][data-turbo-permanent]", count: 1, visible: :all
    assert_selector "#announcements.sr-only", visible: :all
  end

  it "can be drawn on screen with a message, for previews" do
    render_inline(Core::UI::LiveRegionComponent.new(visible: true)) { "Event created." }
    assert_selector "#announcements[aria-live=polite]", text: "Event created."
    assert_no_selector "#announcements.sr-only", visible: :all
  end
end
