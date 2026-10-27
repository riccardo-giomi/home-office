require "test_helper"

describe Core::UI::SelectionBarComponent do
  include ViewComponent::TestHelpers

  def bar(*labels) = render_inline(Core::UI::SelectionBarComponent.new(entries: labels.map { |label| Core::Entity.includes(:record).find(core_entities(label).id) }))

  it "draws nothing when nothing is selected" do
    bar
    assert_no_selector "div[role=group]"
  end

  it "is a labeled region with each selected record as a link and a button that unselects it" do
    bar(:dentist)
    assert_selector "div[role=group][aria-label='Selected records']"
    assert_selector "a", text: "Dentist"
    assert_selector "button[aria-label='Unselect Dentist']"
    assert_selector "form[action='/selection'] input[name=entity_id][value='#{core_entities(:dentist).id}']", visible: :all
    assert_button "Clear selection"
  end

  it "offers to link them only when there are two, and then empties the selection" do
    bar(:dentist)
    assert_no_button "Link these two"
    bar(:dentist, :holiday)
    assert_button "Link these two"
    assert_selector "form[action='/links'] input[name=clear_selection][value='1']", visible: :all
  end

  it "wraps a very long title" do
    planner_items(:dentist).update_columns(title: "W" * 255)
    bar(:dentist)
    assert_selector "a.wrap-anywhere", text: "W" * 255
  end
end
