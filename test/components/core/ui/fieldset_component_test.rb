require "test_helper"

describe Core::UI::FieldsetComponent do
  include ViewComponent::TestHelpers

  it "groups its content under a legend" do
    render_inline(Core::UI::FieldsetComponent.new(legend: "Day hours")) { "<input id='x'>".html_safe }
    assert_selector "fieldset > legend", text: "Day hours"
    assert_selector "fieldset input#x"
  end

  it "points the group at its hint" do
    render_inline(Core::UI::FieldsetComponent.new(legend: "Day hours", hint: "From the first to the last.", id: "hours")) { "x" }
    assert_selector "fieldset[aria-describedby=hours_hint]"
    assert_selector "p#hours_hint", text: "From the first to the last."
  end

  it "has no description without a hint" do
    render_inline(Core::UI::FieldsetComponent.new(legend: "Theme")) { "x" }
    assert_no_selector "fieldset[aria-describedby]"
  end
end
