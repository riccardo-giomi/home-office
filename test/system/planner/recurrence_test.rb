require "test_helper"
require "application_system_test_case"

class Planner::RecurrenceSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }
  let(:series) do
    Planner::Series.create!(user: admin, title: "Gym", notes: "Bring a towel", starts_on: Date.current.beginning_of_week, time_zone: "UTC",
      rrule: "FREQ=DAILY", start_time: "18:00", duration_minutes: 60, tracks_done: 1)
  end

  before do
    admin.update!(time_zone: "UTC", time_format: "24h", first_weekday: 1, locale: "en")
    series
  end

  %w[light dark].each do |theme|
    it "has no axe violations in the #{theme} theme" do
      admin.update!(theme:)
      sign_in_through_form admin
      [planner_calendar_path(view: "month"), planner_calendar_path(view: "week"), planner_calendar_path(view: "day"), planner_agenda_path(view: "week")].each do |path|
        visit path
        assert_text "Gym", wait: 5
        assert_accessible
      end
      visit planner_series_occurrence_path(series, Date.current.iso8601)
      assert_text "Bring a towel"
      assert_accessible
      visit edit_planner_series_occurrence_path(series, Date.current.iso8601)
      assert_accessible
    end
  end

  it "marks an occurrence as repeating, opens it in the dialog and saves nothing by looking" do
    sign_in_through_form admin
    visit planner_agenda_path(view: "day")
    assert_text "18:00–19:00"
    assert_selector "span[role=img][aria-label=Repeats]"
    click_link "Gym"
    within("#item-dialog") { assert_text "Bring a towel" }
    assert_equal 0, Planner::Event.where(series_id: series.id).count
  end

  it "fits a 320 px screen" do
    sign_in_through_form admin
    page.current_window.resize_to(320, 640)
    visit planner_agenda_path(view: "week")
    assert_fits_small_screen
    visit planner_calendar_path(view: "day")
    assert_fits_small_screen
    visit planner_series_occurrence_path(series, Date.current.iso8601)
    assert_fits_small_screen
  end

  it "saves an occurrence when its box is ticked in the agenda, and only that one" do
    sign_in_through_form admin
    visit planner_agenda_path(view: "week")
    gym_boxes = "input[type=checkbox][aria-label='#{I18n.t("planner.calendars.show.done_label", title: "Gym")}']"
    find(gym_boxes, match: :first).click
    assert_selector "#{gym_boxes}[checked]", wait: 5
    assert_equal 1, Planner::Event.where(series_id: series.id).count
    assert Planner::Event.find_by!(series_id: series.id).done?
    assert_equal 6, all("#{gym_boxes}:not([checked])").size
  end

  it "links an unsaved occurrence from its dialog, which saves it and stays open with the Links section" do
    sign_in_through_form admin
    visit planner_agenda_path(view: "day")
    click_link "Gym"
    within("#item-dialog") do
      assert_no_selector "#links-section"
      click_button I18n.t("core.ui.links_section.add")
      assert_selector "#links-section", wait: 5
      assert_no_selector "#links-placeholder"
    end
    assert_equal 1, Planner::Event.where(series_id: series.id).count
  end

  it "ticks an unsaved occurrence from its dialog, which saves it and shows the Links section" do
    sign_in_through_form admin
    visit planner_agenda_path(view: "day")
    click_link "Gym"
    within("#item-dialog") do
      assert_selector "#links-placeholder"
      find("input[aria-label='#{I18n.t("planner.calendars.show.done_label", title: "Gym")}']").click
      assert_selector "input[type=checkbox][checked]", wait: 5
      assert_selector "#links-section"
    end
    assert Planner::Event.find_by!(series_id: series.id).done?
  end
end
