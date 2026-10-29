require "test_helper"

# What ticking, abandoning and linking do to an occurrence nobody has saved yet: the change saves it first, once.
class Planner::OccurrenceChangesTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }
  let(:series) do
    Planner::Series.create!(user: admin, title: "Rent", starts_on: Date.new(2026, 10, 1), time_zone: "Europe/Rome", rrule: "FREQ=MONTHLY;BYMONTHDAY=1", tracks_done: 1)
  end
  let(:frame) { {"Turbo-Frame" => "item-dialog-frame"} }

  def tick(on, **options) = patch(planner_series_occurrence_completion_path(series, on), **options)

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 5, 12)
    sign_in_as admin
  end

  describe "ticking" do
    it "saves the occurrence done, once, and says so" do
      assert_difference "Planner::Event.count", 1 do
        tick "2026-11-01", params: {done: "1"}
      end
      row = Planner::Event.find_by!(series_id: series.id)
      assert_equal [Date.new(2026, 11, 1), true], [row.occurrence_on, row.done?]
      assert_equal "Marked done: Rent", flash[:notice]
      assert_redirected_to planner_calendar_path(date: "2026-11-01")
    end

    it "ticks the months ahead one by one, each on its own" do
      %w[2026-11-01 2026-12-01 2027-01-01].each { |on| tick on, params: {done: "1"} }
      assert_equal 3, Planner::Event.where(series_id: series.id).count
      tick "2026-12-01", params: {done: "0"}
      assert_equal [true, false, true], Planner::Event.where(series_id: series.id).order(:occurrence_on).map(&:done?)
      assert_equal 3, Planner::Event.where(series_id: series.id).count
    end

    it "ticks the row that is already there, and the one another request saved first" do
      row = series.materialize(Date.new(2026, 11, 1))
      assert_no_difference "Planner::Event.count" do
        tick "2026-11-01", params: {done: "1"}
      end
      assert row.reload.done?
    end

    it "saves nothing when the series does not track done" do
      plain = Planner::Series.create!(user: admin, title: "Plain", starts_on: Date.new(2026, 10, 1), time_zone: "Europe/Rome", rrule: "FREQ=DAILY")
      assert_no_difference "Planner::Event.count" do
        patch planner_series_occurrence_completion_path(plain, "2026-10-06"), params: {done: "1"}
      end
      assert_equal "That item cannot be ticked.", flash[:alert]
    end

    it "in the dialog refreshes the page behind and redraws the details with the saved event, keeping the dialog open" do
      tick "2026-11-01", headers: frame, params: {done: "1"}
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_select "turbo-stream[action=refresh]", 1
      row = Planner::Event.find_by!(series_id: series.id)
      assert_select "turbo-stream[action=update][target=item-dialog-frame] form[action='#{planner_item_completion_path(row)}'] input[type=checkbox][checked]", 1
      assert_select "turbo-stream[action=close_dialog]", 0
    end

    it "is not found for a date the rule does not give, another user's series, a trashed series; nothing is saved" do
      theirs = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 1), time_zone: "Europe/Rome", rrule: "FREQ=DAILY", tracks_done: 1)
      tick "2026-11-02", params: {done: "1"}
      assert_response :not_found
      patch planner_series_occurrence_completion_path(theirs, "2026-10-06"), params: {done: "1"}
      assert_response :not_found
      series.trash
      tick "2026-11-01", params: {done: "1"}
      assert_response :not_found
      assert_equal 0, Planner::Event.where(series_id: [series.id, theirs.id]).count
    end
  end

  describe "an address by item id" do
    it "is not turned into an address by series by a query string" do
      item = planner_items(:rent_open)
      patch planner_item_completion_path(item, series_id: series.id, occurrence_on: "2026-11-05"), params: {done: "1"}
      assert item.reload.done?
      assert_equal 0, Planner::Event.where(series_id: series.id).count
      series.trash
      patch planner_item_restoration_path(planner_items(:trashed_event), series_id: series.id)
      assert_redirected_to planner_trash_path
      refute_predicate Planner::Event.includes(:entity).find(planner_items(:trashed_event).id), :trashed?
    end
  end

  describe "abandoning" do
    it "saves the occurrence in its new state" do
      assert_difference "Planner::Event.count", 1 do
        patch planner_series_occurrence_state_path(series, "2026-11-01"), params: {state: "cancelled"}
      end
      assert_equal "cancelled", Planner::Event.find_by!(series_id: series.id).state
    end

    it "saves nothing for a change that is not possible" do
      assert_no_difference "Planner::Event.count" do
        patch planner_series_occurrence_state_path(series, "2026-11-01"), params: {state: "active"}
      end
      assert_equal "That change is not possible.", flash[:alert]
    end
  end

  describe "linking" do
    it "shows an unsaved occurrence's page with an Add link button and no Links section" do
      get planner_series_occurrence_path(series, "2026-11-01")
      assert_select "#links-section", 0
      assert_select "form[action='#{planner_series_occurrence_materialization_path(series, "2026-11-01")}'] button", text: "Add link"
    end

    it "saves the occurrence and shows its page with the Links section, in the dialog and on a full page" do
      assert_difference "Planner::Event.count", 1 do
        post planner_series_occurrence_materialization_path(series, "2026-11-01"), headers: frame
      end
      row = Planner::Event.find_by!(series_id: series.id)
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_select "turbo-stream[action=update][target=item-dialog-frame] #links-section", 1
      assert_no_difference "Planner::Event.count" do
        post planner_series_occurrence_materialization_path(series, "2026-11-01")
      end
      assert_redirected_to planner_event_path(row)
    end

    it "is not found for a date the rule does not give or another user's series" do
      post planner_series_occurrence_materialization_path(series, "2026-11-02")
      assert_response :not_found
      theirs = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 1), time_zone: "Europe/Rome", rrule: "FREQ=DAILY")
      post planner_series_occurrence_materialization_path(theirs, "2026-10-06")
      assert_response :not_found
      assert_equal 0, Planner::Event.where(series_id: [series.id, theirs.id]).count
    end
  end
end
