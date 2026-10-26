require "test_helper"

describe Core::UI::LinksSectionComponent do
  include ViewComponent::TestHelpers

  def section(label, notice: nil, **options)
    id = core_entities(label).id
    render_inline(Core::UI::LinksSectionComponent.new(entity_id: id, ends: Core::LinkIndex.new(id).ends_of(id), notice:, **options))
  end

  it "is a labeled section whose heading counts the links that are not in the trash" do
    section(:dentist)
    assert_selector "div#links-section[role=group][aria-labelledby=links-section-heading]"
    assert_selector "h2#links-section-heading[tabindex='-1']", text: "Links (2)"
  end

  it "lists each other end: its title as a link to its page, with kind, day and status" do
    section(:dentist)
    assert_selector "a[href='#{Rails.application.routes.url_helpers.planner_task_path(planner_items(:pay_rent_task))}']", text: "Pay the rent"
    assert_text "Task · 10/07/2026"
    assert_text "Todo"
  end

  it "has a Change link and a Remove button named for the other end, on every row" do
    section(:dentist)
    assert_selector "a[href*='/links/new'][data-turbo-frame=links-section-picker]", text: "Change", count: 3
    assert_selector "form[action^='/links/'] input[name=_method][value=delete]", count: 3, visible: :all
    assert_selector "button[aria-label='Remove link to Pay the rent']"
  end

  it "shows an end in the trash last, struck through, in words, with a way to the trash" do
    section(:dentist)
    assert_selector "li:last-child s", text: planner_items(:trashed_task).title
    assert_selector "li:last-child", text: "in the trash"
    assert_selector "li:last-child a[href='/trash']"
    assert_no_selector "li:last-child a[href*='planner/tasks']"
  end

  it "opens the picker into its own frame" do
    section(:dentist)
    assert_selector "a[href^='/links/new?entity_id='][data-turbo-frame=links-section-picker]", text: "Add link"
    assert_selector "turbo-frame#links-section-picker"
  end

  it "says when there are none" do
    section(:holiday)
    assert_selector "h2", text: "Links (0)"
    assert_text "Nothing linked yet."
  end

  it "says what just happened, in a status the reader hears" do
    section(:dentist, notice: "Link to Pay the rent removed.")
    assert_selector "p[role=status]", text: "Link to Pay the rent removed."
  end

  it "wraps a very long unbroken title" do
    planner_items(:pay_rent_task).update_columns(title: "W" * 255)
    section(:dentist)
    assert_selector "li .wrap-anywhere", text: "W" * 255
  end
end
