require "application_system_test_case"

class Planner::EventsSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  def make_event(title, days_ahead: 1, **attrs)
    Planner::Event.create!(user: admin, title:, day: Date.current + days_ahead, **attrs)
  end

  def field(attribute) = Planner::Event.human_attribute_name(attribute)

  before do
    admin.update!(time_zone: "UTC", time_format: "24h")
    sign_in_through_form admin
  end

  it "creates an all-day event and lists it" do
    visit planner_events_path
    click_link I18n.t("planner.events.index.new")
    fill_in field(:title), with: "Dentist"
    fill_in field(:day), with: Date.current + 3
    click_button I18n.t("planner.events.form.submit")
    assert_text I18n.t("planner.events.create.created")
    assert_selector "td", text: "Dentist"
    assert_selector "td", text: I18n.t("planner.events.index.all_day")
  end

  it "fills the end 30 minutes after the start until the end is typed" do
    visit new_planner_event_path
    fill_in field(:start_time), with: Time.utc(2000, 1, 1, 9, 30)
    assert_equal "10:00", find_field(field(:end_time)).value
    fill_in field(:start_time), with: Time.utc(2000, 1, 1, 11, 0)
    assert_equal "11:30", find_field(field(:end_time)).value
    fill_in field(:end_time), with: Time.utc(2000, 1, 1, 12, 15)
    fill_in field(:start_time), with: Time.utc(2000, 1, 1, 8, 0)
    assert_equal "12:15", find_field(field(:end_time)).value
  end

  it "stops the suggested end at 23:59 and suggests nothing from 23:59" do
    visit new_planner_event_path
    fill_in field(:start_time), with: Time.utc(2000, 1, 1, 23, 45)
    assert_equal "23:59", find_field(field(:end_time)).value
    fill_in field(:start_time), with: Time.utc(2000, 1, 1, 23, 59)
    assert_equal "", find_field(field(:end_time)).value
  end

  it "keeps the keyboard on the checkbox while ticking done" do
    make_event "Pay the rent", tracks_done: 1
    visit planner_events_path
    id = "done_event_#{Planner::Event.find_by!(title: "Pay the rent").id}"
    find("##{id}").send_keys(:space)
    assert_text I18n.t("planner.completions.update.done", title: "Pay the rent")
    assert_selector "s", text: "Pay the rent"
    assert_selector "input[type=checkbox][checked]"
    assert_equal id, evaluate_script("document.activeElement.id")
    find("##{id}").send_keys(:space)
    assert_no_selector "s", text: "Pay the rent"
  end

  it "deletes an event after a confirmation" do
    event = make_event "Old appointment"
    visit edit_planner_event_path(event)
    click_button I18n.t("planner.events.edit.delete")
    within("#delete-event") { click_button I18n.t("planner.events.edit.delete_confirm") }
    assert_text I18n.t("planner.events.destroy.deleted")
    assert_no_selector "td", text: "Old appointment"
  end

  it "moves focus to the error summary and from there to the field" do
    visit new_planner_event_path
    fill_in field(:title), with: "Meeting"
    fill_in field(:start_time), with: Time.utc(2000, 1, 1, 10, 0)
    fill_in field(:end_time), with: Time.utc(2000, 1, 1, 9, 0)
    click_button I18n.t("planner.events.form.submit")
    assert_selector "#error-summary"
    assert_equal "error-summary", evaluate_script("document.activeElement.id")
    # a plain left-aligned list: no bullets, no centered text
    left = evaluate_script("document.querySelector('#error-summary ul').getBoundingClientRect().left - document.querySelector('#error-summary').getBoundingClientRect().left")
    assert_operator left, :<=, 48, "the error list starts #{left}px in from the alert's edge"
    assert_equal ["none", "start"], evaluate_script("(() => { const li = getComputedStyle(document.querySelector('#error-summary li')); return [li.listStyleType, getComputedStyle(document.querySelector('#error-summary ul')).textAlign] })()")
    find("#error-summary a", match: :first).click
    assert_equal "planner_event_end_time", evaluate_script("document.activeElement.id")
  end

  %w[light dark].each do |theme|
    it "has no axe violations in the #{theme} theme" do
      admin.update!(theme:)
      make_event "Pay the rent", tracks_done: 1, done_at: Time.current
      make_event "Standup", start_time: "09:00", end_time: "09:30"
      26.times { |i| make_event "Bulk #{i}", days_ahead: 5 + i }
      visit planner_events_path
      assert_selector "nav[aria-label] a[aria-current=page]"
      assert_accessible
      visit planner_events_path(page: 2)
      assert_accessible
      visit new_planner_event_path
      assert_accessible
      fill_in field(:title), with: "Meeting"
      fill_in field(:start_time), with: Time.utc(2000, 1, 1, 10, 0)
      fill_in field(:end_time), with: Time.utc(2000, 1, 1, 9, 0)
      click_button I18n.t("planner.events.form.submit")
      assert_selector "#error-summary"
      assert_accessible
      shown = make_event("Show me", notes: "Bring the files", tracks_done: 1)
      visit planner_event_path(shown)
      assert_selector "h1", text: "Show me"
      assert_accessible
      visit edit_planner_event_path(make_event("Edit me"))
      assert_accessible
      click_button I18n.t("planner.events.edit.delete")
      sleep 0.4
      assert_accessible(within: "#delete-event")
    end
  end

  it "draws the current page at full strength, not as a disabled control" do
    26.times { |i| make_event "Bulk #{i}", days_ahead: 5 + i }
    visit planner_events_path(page: 2)
    # axe leaves aria-disabled links out of its contrast check, so look at the color itself
    color = evaluate_script("getComputedStyle(document.querySelector(\"nav[aria-label='#{I18n.t("planner.events.index.pages")}'] a[aria-current=page]\")).color")
    refute_match %r{/}, color, "the current page link is drawn translucent: #{color}"
  end

  it "fits a 320 px screen with touch-sized targets" do
    make_event "A very long title that has to wrap instead of pushing the page sideways at 320 pixels wide", tracks_done: 1
    26.times { |i| make_event "Bulk #{i}", days_ahead: 5 + i }
    page.current_window.resize_to(320, 640)
    visit planner_events_path
    assert_selector "nav[aria-label] a[aria-current=page]"
    assert_fits_small_screen
    visit planner_events_path(page: 2)
    assert_fits_small_screen
    visit new_planner_event_path
    assert_fits_small_screen
    visit edit_planner_event_path(make_event("Edit me"))
    assert_fits_small_screen
    visit planner_event_path(make_event("Show me", notes: "Bring the files", tracks_done: 1))
    assert_fits_small_screen
  end
end
