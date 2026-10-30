require "test_helper"

# Editing an occurrence of a series with a scope: this event, this and following, all. Through the occurrence address
# (an unsaved occurrence, or a date that has a row) and through the event's own address (a row).
class Planner::SeriesScopesTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }
  let(:rent) do
    Planner::Series.create!(user: admin, title: "Rent", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=MONTHLY;BYMONTHDAY=5",
      start_time: "09:00", duration_minutes: 60, tracks_done: 1)
  end
  let(:unsaved_occurrence_path) { planner_series_occurrence_path(rent, "2026-11-05") }
  let(:frame) { {"Turbo-Frame" => "item-dialog-frame"} }

  def event_params(**overrides) = {title: "Rent", notes: "", priority: "normal", tracks_done: "1", day: "2026-11-05", start_time: "09:00", end_time: "10:00"}.merge(overrides)

  def repeat_params(**overrides) = {frequency: "monthly", interval: "1", monthly: "day", ends: "never"}.merge(overrides)

  def update(path = unsaved_occurrence_path, scope: nil, repeat: repeat_params, headers: {}, **overrides)
    patch path, headers:, params: {planner_event: event_params(**overrides), repeat:, apply: ({scope:} if scope)}.compact
  end

  def newer = Planner::Series.where(user_id: admin.id).where.not(id: rent.id).sole

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 5, 12)
    sign_in_as admin
  end

  describe "the edit page" do
    it "offers the rule of the series and the three scopes, this event chosen, for an unsaved occurrence and for an event" do
      row = rent.materialize(Date.new(2026, 12, 5))
      [edit_planner_series_occurrence_path(rent, "2026-11-05"), edit_planner_event_path(row)].each do |path|
        get path
        assert_response :success
        assert_select "select[name='repeat[frequency]'] option[selected][value=monthly]"
        assert_select "select[name='repeat[frequency]'] option[value=never]", 0
        assert_select "fieldset#apply-scope input[type=radio][name='apply[scope]']", 3
        assert_select "fieldset#apply-scope input[type=radio][value=this][checked]"
        assert_equal %w[this following all], css_select("fieldset#apply-scope input").map { |radio| radio["value"] }
      end
    end

    it "does not offer them for an event that is not part of a series" do
      get edit_planner_event_path(planner_items(:dentist))
      assert_select "fieldset#repeat-fields", 0
      assert_select "fieldset#apply-scope", 0
    end
  end

  describe "this event" do
    it "is the default, and changes the occurrence only" do
      update title: "Rent, late"
      row = Planner::Event.find_by!(series_id: rent.id)
      assert_equal ["Rent, late", Date.new(2026, 11, 5)], [row.title, row.occurrence_on]
      assert_equal "Rent", rent.reload.title
      assert_equal 1, Planner::Series.count
    end

    it "refuses a change of the rule, saying which scopes can make it, and saves nothing" do
      update scope: "this", repeat: repeat_params(interval: "2")
      assert_response :unprocessable_content
      assert_select "#error-summary a[href='#repeat_frequency']", text: /choose This and following events or All events/
      assert_equal 0, Planner::Event.where(series_id: rent.id).count
    end

    it "takes a junk scope for this event" do
      update scope: "everything", title: "Rent, late"
      assert_equal "Rent, late", Planner::Event.find_by!(series_id: rent.id).title
      assert_equal 1, Planner::Series.count
    end
  end

  describe "this and following" do
    it "splits the series and sends the user back to the page they came from, saving no event for an unsaved occurrence" do
      assert_no_difference "Planner::Event.count" do
        update scope: "following", title: "Rent and bills", back: planner_agenda_path
      end
      assert_equal Date.new(2026, 11, 4), rent.reload.ends_on
      assert_equal ["Rent and bills", Date.new(2026, 11, 5)], [newer.title, newer.starts_on]
      assert_redirected_to planner_calendar_path(date: "2026-11-05")
      assert_equal "Event updated.", flash[:notice]
    end

    it "moves the day for good" do
      update scope: "following", day: "2026-11-10"
      assert_equal [Date.new(2026, 11, 10), "FREQ=MONTHLY;BYMONTHDAY=10"], [newer.starts_on, newer.rrule]
    end

    it "changes the rule from there on" do
      update scope: "following", repeat: repeat_params(frequency: "weekly", weekdays: ["TH"])
      assert_equal "FREQ=WEEKLY;BYDAY=TH", newer.rrule
    end

    it "closes the dialog and refreshes the page behind" do
      update scope: "following", title: "Rent and bills", headers: frame
      assert_select "turbo-stream[action=close_dialog]", 1
      assert_select "turbo-stream[action=refresh]", 1
    end

    it "shows what is wrong and keeps what was typed" do
      update scope: "following", day: "2026-10-03", title: "Typed"
      assert_response :unprocessable_content
      assert_select "#error-summary a[href='#planner_event_day']", text: /must come after 5 Oct 2026/
      assert_select "input[name='planner_event[title]'][value=Typed]"
      assert_select "fieldset#apply-scope input[value=following][checked]"
      assert_equal 1, Planner::Series.count
    end

    it "works from the address of an event too" do
      row = rent.materialize(Date.new(2026, 11, 5))
      patch planner_event_path(row), params: {planner_event: event_params(title: "Rent and bills"), repeat: repeat_params, apply: {scope: "following"}}
      assert_equal "Rent and bills", row.reload.title
      assert_equal newer.id, row.series_id
    end
  end

  describe "all" do
    it "changes every part of the series and leaves the day alone" do
      update scope: "all", title: "Housing", day: "2026-11-20"
      assert_equal "Housing", rent.reload.title
      assert_equal 1, Planner::Series.count
      assert_equal Date.new(2026, 10, 5), rent.starts_on
      assert_equal 0, Planner::Event.where(series_id: rent.id).count
    end

    it "puts a split series back together when the rule changes" do
      update scope: "following", day: "2026-11-10"
      update planner_series_occurrence_path(rent, "2026-10-05"), scope: "all", repeat: repeat_params(interval: "2"), day: "2026-10-05"
      assert_equal 1, Planner::Series.count
      assert_equal "FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=5", rent.reload.rrule
    end
  end

  describe "someone else's series, a trashed series" do
    it "is not found, and nothing changes" do
      theirs = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY")
      update planner_series_occurrence_path(theirs, "2026-10-06"), scope: "all", title: "Mine now"
      assert_response :not_found
      rent.trash
      update scope: "all", title: "Nope"
      assert_response :not_found
      assert_equal "Theirs", theirs.reload.title
    end
  end
end
