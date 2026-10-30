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

  describe "the repeat fields of the event form" do
    before { sign_in_through_form admin }

    def fill_event(title: "Standup", day: "2026-10-05")
      fill_in "planner_event_title", with: title
      fill_in "planner_event_day", with: Date.parse(day)
    end

    it "shows only the fields the frequency and the end use" do
      visit new_planner_event_path
      assert_no_selector "#repeat-weekdays"
      assert_no_selector "#repeat-monthly"
      assert_no_selector "#repeat-ends"
      select I18n.t("planner.repeat.frequencies.weekly"), from: "repeat_frequency"
      assert_selector "#repeat-weekdays"
      assert_no_selector "#repeat-monthly"
      assert_selector "#repeat-ends"
      assert_no_selector "#repeat_until_on"
      choose I18n.t("planner.repeat.ends.until")
      assert_selector "#repeat_until_on"
      assert_no_selector "#repeat_count"
      choose I18n.t("planner.repeat.ends.count")
      assert_selector "#repeat_count"
      assert_no_selector "#repeat_until_on"
      select I18n.t("planner.repeat.frequencies.monthly"), from: "repeat_frequency"
      assert_selector "#repeat-monthly"
      assert_no_selector "#repeat-weekdays"
      select I18n.t("planner.repeat.frequencies.never"), from: "repeat_frequency"
      assert_no_selector "#repeat-ends"
    end

    it "reads the rule back in words, in a polite live region, as it changes" do
      visit new_planner_event_path
      fill_event
      assert_selector "[data-repeat-fields-target=summary][aria-live=polite]", text: "", visible: :all
      select I18n.t("planner.repeat.frequencies.weekly"), from: "repeat_frequency"
      assert_selector "[data-repeat-fields-target=summary]", text: "Every week on Mon", wait: 5
      check "Wednesday"
      assert_selector "[data-repeat-fields-target=summary]", text: "Every week on Mon, Wed", wait: 5
      fill_in "repeat_interval", with: 2
      assert_selector "[data-repeat-fields-target=summary]", text: "Every 2 weeks on Mon, Wed", wait: 5
      choose I18n.t("planner.repeat.ends.count")
      fill_in "repeat_count", with: 6
      assert_selector "[data-repeat-fields-target=summary]", text: "Every 2 weeks on Mon, Wed, 6 times", wait: 5
      fill_in "planner_event_day", with: Date.new(2026, 10, 7)
      uncheck "Monday"
      assert_selector "[data-repeat-fields-target=summary]", text: "Every 2 weeks on Wed, 6 times", wait: 5
    end

    it "makes a series from the form and shows its occurrences" do
      visit new_planner_event_path
      fill_event(title: "Standup", day: Date.current.beginning_of_week.iso8601)
      select I18n.t("planner.repeat.frequencies.weekly"), from: "repeat_frequency"
      check "Wednesday"
      click_button I18n.t("planner.kinds.event.submit")
      assert_text I18n.t("planner.kinds.event.created")
      series = Planner::Series.find_by!(title: "Standup")
      assert_equal "FREQ=WEEKLY;BYDAY=MO,WE", series.rrule
      assert_equal 0, Planner::Event.where(title: "Standup").count
      visit planner_agenda_path(view: "week")
      assert_selector "a", text: "Standup", minimum: 2
    end

    it "keeps what was typed and says what is wrong, in the summary of errors" do
      visit new_planner_event_path
      fill_event
      select I18n.t("planner.repeat.frequencies.daily"), from: "repeat_frequency"
      fill_in "repeat_interval", with: 3
      choose I18n.t("planner.repeat.ends.until")
      fill_in "repeat_until_on", with: Date.new(2026, 10, 1)
      click_button I18n.t("planner.kinds.event.submit")
      assert_selector "#error-summary a[href='#repeat_until_on']"
      find("#error-summary a[href='#repeat_until_on']").click
      assert_equal "repeat_until_on", evaluate_script("document.activeElement.id")
      assert_equal ["daily", "3", "standup"], [find("#repeat_frequency").value, find("#repeat_interval").value, find("#planner_event_title").value.downcase]
      assert_selector "#repeat-ends"
    end

    %w[light dark].each do |theme|
      it "has no axe violations in the #{theme} theme" do
        admin.update!(theme:)
        visit new_planner_event_path
        assert_accessible
        select I18n.t("planner.repeat.frequencies.weekly"), from: "repeat_frequency"
        choose I18n.t("planner.repeat.ends.until")
        assert_accessible
        select I18n.t("planner.repeat.frequencies.monthly"), from: "repeat_frequency"
        choose I18n.t("planner.repeat.ends.count")
        assert_accessible
        fill_event
        fill_in "repeat_count", with: 3
        choose I18n.t("planner.repeat.ends.until")
        fill_in "repeat_until_on", with: Date.new(2026, 10, 1)
        click_button I18n.t("planner.kinds.event.submit")
        assert_selector "#error-summary"
        assert_accessible
      end
    end

    it "fits a 320 px screen" do
      page.current_window.resize_to(320, 640)
      visit new_planner_event_path
      assert_fits_small_screen
      select I18n.t("planner.repeat.frequencies.weekly"), from: "repeat_frequency"
      choose I18n.t("planner.repeat.ends.until")
      assert_fits_small_screen
      select I18n.t("planner.repeat.frequencies.monthly"), from: "repeat_frequency"
      assert_fits_small_screen
    end

    it "works from the dialog too" do
      visit planner_calendar_path(view: "month")
      click_link I18n.t("planner.calendars.show.new")
      within("#item-dialog") do
        fill_in "planner_event_title", with: "Rent"
        select I18n.t("planner.repeat.frequencies.monthly"), from: "repeat_frequency"
        click_button I18n.t("planner.kinds.event.submit")
      end
      assert_no_selector "#item-dialog[open]", wait: 5
      assert_equal 1, Planner::Series.where(title: "Rent").count
    end
  end
end
