require "test_helper"

# The pages of one occurrence of a series, named by the series and the date the rule gave it. They are the event
# pages (this controller inherits them; Planner::EventsControllerTest covers the shared behaviour): what differs
# is finding the event, which may be a ghost nobody has saved yet, and saving it on the first change.
class Planner::OccurrencesControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }
  let(:series) do
    Planner::Series.create!(user: admin, title: "Gym", notes: "Bring a towel", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome",
      rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60, tracks_done: 1)
  end
  let(:ghost_path) { planner_series_occurrence_path(series, "2026-10-12") }
  let(:frame) { {"Turbo-Frame" => "item-dialog-frame"} }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 5, 12)
    sign_in_as admin
  end

  describe "showing" do
    it "shows a ghost without saving anything" do
      assert_no_difference ["Planner::Event.count", "Core::Entity.count"] do
        get ghost_path
      end
      assert_response :success
      assert_select "h1", "Gym"
      assert_select "dd", text: /Bring a towel/
      assert_select "dd", text: /18:00.*19:00/m
      assert_select "a[href='#{edit_planner_series_occurrence_path(series, "2026-10-12")}']"
    end

    it "shows the row when the date has one" do
      row = series.materialize(Date.new(2026, 10, 12))
      row.update!(title: "Gym, leg day")
      get ghost_path
      assert_select "h1", "Gym, leg day"
    end

    it "shows the dialog content in a frame request" do
      get ghost_path, headers: frame
      assert_select "turbo-frame#item-dialog-frame h1#dialog-title", "Gym"
    end

    it "answers 404 for a date the rule does not give, an excluded one, a malformed one, a trashed row" do
      series.exclusions.create!(user_id: admin.id, excluded_on: Date.new(2026, 10, 19))
      series.materialize(Date.new(2026, 10, 26)).trash
      %w[2026-10-13 2026-10-19 2026-10-26 2026-09-28 nonsense 2026-02-30].each do |on|
        get planner_series_occurrence_path(series, on)
        assert_response :not_found, on
      end
    end

    it "answers 404 for another user's series and for a trashed series, saving nothing" do
      theirs = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY")
      get planner_series_occurrence_path(theirs, "2026-10-06")
      assert_response :not_found
      series.trash
      get ghost_path
      assert_response :not_found
      assert_equal 0, Planner::Event.where(series_id: [theirs.id, series.id]).count
    end

    it "sends anonymous visitors to sign in" do
      sign_out
      get ghost_path
      assert_redirected_to new_session_path
    end
  end

  describe "editing" do
    it "shows the form of a ghost, posting to the occurrence" do
      get edit_planner_series_occurrence_path(series, "2026-10-12")
      assert_response :success
      assert_select "form#item-form[action='#{ghost_path}'] input[name=_method][value=patch]"
      assert_select "input[name='planner_event[title]'][value=Gym]"
      assert_select "input[name='planner_event[start_time]'][value='18:00']"
      assert_select "h1", text: /Gym/
    end

    it "saves the ghost as an event on the first change, keeping where it came from" do
      assert_difference "Planner::Event.count", 1 do
        patch ghost_path, params: {planner_event: {title: "Gym, legs", notes: "", day: "2026-10-12", start_time: "18:00", end_time: "19:00", tracks_done: "1", priority: "normal"}}
      end
      row = Planner::Event.find_by!(series_id: series.id)
      assert_equal [admin.id, "Gym, legs", Date.new(2026, 10, 12), Date.new(2026, 10, 12)], [row.user_id, row.title, row.day, row.occurrence_on]
      assert_redirected_to planner_event_path(row)
      assert_equal I18n.t("planner.kinds.event.updated"), flash[:notice]
    end

    it "moves the occurrence to another day and keeps its date from the rule" do
      patch ghost_path, params: {planner_event: {title: "Gym", day: "2026-10-14", start_time: "18:00", end_time: "19:00", tracks_done: "1"}}
      row = Planner::Event.find_by!(series_id: series.id)
      assert_equal [Date.new(2026, 10, 14), Date.new(2026, 10, 12)], [row.day, row.occurrence_on]
      assert_equal Time.utc(2026, 10, 14, 16), row.starts_at
    end

    it "saves nothing and shows the errors when the change is invalid" do
      assert_no_difference "Planner::Event.count" do
        patch ghost_path, params: {planner_event: {title: " ", day: "2026-10-12", start_time: "18:00", end_time: "19:00"}}
      end
      assert_response :unprocessable_content
      assert_select "#error-summary"
      assert_select "h1", text: /Gym/
    end

    it "updates the row when the date already has one, and when another request saved the ghost first" do
      row = series.materialize(Date.new(2026, 10, 12))
      assert_no_difference "Planner::Event.count" do
        patch ghost_path, params: {planner_event: {title: "Renamed", day: "2026-10-12", start_time: "18:00", end_time: "19:00"}}
      end
      assert_equal "Renamed", row.reload.title
    end

    it "never lets the request choose the series, the date, the owner or the state" do
      patch ghost_path, params: {planner_event: {title: "Gym", day: "2026-10-12", start_time: "18:00", end_time: "19:00", series_id: 0, occurrence_on: "2030-01-01", user_id: users(:other_admin).id, state: "abandoned"}}
      row = Planner::Event.find_by!(series_id: series.id)
      assert_equal [series.id, Date.new(2026, 10, 12), admin.id, "active"], [row.series_id, row.occurrence_on, row.user_id, row.state]
    end

    it "answers a dialog change by refreshing the page behind and closing the dialog" do
      patch ghost_path, headers: frame, params: {planner_event: {title: "Gym", day: "2026-10-12", start_time: "18:00", end_time: "19:00"}}
      assert_select "turbo-stream[action=refresh]", 1
      assert_select "turbo-stream[action=close_dialog]", 1
    end

    it "is not found for another user's series" do
      theirs = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY")
      patch planner_series_occurrence_path(theirs, "2026-10-06"), params: {planner_event: {title: "Mine now"}}
      assert_response :not_found
      assert_equal 0, Planner::Event.where(series_id: theirs.id).count
    end
  end

  describe "going back" do
    it "carries the page the visit began on, and returns to the occurrence after a change" do
      back = planner_agenda_path(view: "week", date: "2026-10-12")
      get planner_series_occurrence_path(series, "2026-10-12", back:)
      assert_select "a[href='#{back}']", text: "Back to agenda"
      patch planner_series_occurrence_path(series, "2026-10-12"), params: {back:, planner_event: {title: "Gym", day: "2026-10-12", start_time: "18:00", end_time: "19:00"}}
      assert_redirected_to planner_event_path(Planner::Event.find_by!(series_id: series.id), back:)
    end
  end
end
