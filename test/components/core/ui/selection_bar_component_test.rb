require "test_helper"

describe Core::UI::SelectionBarComponent do
  include ViewComponent::TestHelpers

  def bar(*labels, **options)
    entries = labels.map { |label| Core::Entity.includes(:record).find(core_entities(label).id) }
    render_inline(Core::UI::SelectionBarComponent.new(entries:, **options))
  end

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

  it "opens each record in the dialog of its kind, on a page that has it" do
    bar(:dentist, dialog_frames: ["item-dialog-frame"])
    assert_selector "a[href='#{Rails.application.routes.url_helpers.planner_event_path(planner_items(:dentist))}'][data-turbo-frame='item-dialog-frame']", text: "Dentist"
  end

  it "leads to the page and view that hold each record, on a page without that dialog" do
    bar(:dentist)
    assert_selector "a[href='/planner/calendar?date=2026-10-07&view=day']:not([data-turbo-frame])", text: "Dentist"
  end

  it "wraps a very long title" do
    planner_items(:dentist).update_columns(title: "W" * 255)
    bar(:dentist)
    assert_selector "a.wrap-anywhere", text: "W" * 255
  end
end
