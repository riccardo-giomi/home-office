require "test_helper"

# Ticking is the same for every item that has a done box
class Planner::CompletionsControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 5, 12)
    sign_in_as admin
  end

  it "in the dialog, refreshes the page behind and redraws the details inside the dialog, keeping it open" do
    patch planner_item_completion_path(planner_items(:rent_open)), headers: {"Turbo-Frame" => "item-dialog-frame"}, params: {done: "1"}
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=refresh]:not([request-id])", 1
    assert_select "turbo-stream[action=update][target=item-dialog-frame][method=morph] input[type=checkbox][checked]", 1
    assert_select "turbo-stream[action=update] template dd time", minimum: 2
    assert_select "turbo-stream[action=close_dialog]", 0
    assert planner_items(:rent_open).reload.done?
  end

  it "sets and clears done_at on an event that tracks it" do
    event = planner_items(:rent_open)
    patch planner_item_completion_path(event), params: {done: "1"}
    assert_redirected_to planner_calendar_path(date: "2026-11-01")
    assert event.reload.done?
    patch planner_item_completion_path(event), params: {done: "0"}
    assert_not event.reload.done?
  end

  it "announces the change" do
    patch planner_item_completion_path(planner_items(:rent_open)), params: {done: "1"}
    assert_equal "Marked done: Rent November", flash[:notice]
    patch planner_item_completion_path(planner_items(:rent_open)), params: {done: "0"}
    assert_equal "Marked not done: Rent November", flash[:notice]
  end

  it "does nothing to an event that does not track done" do
    patch planner_item_completion_path(planner_items(:holiday)), params: {done: "1"}
    assert_nil planner_items(:holiday).reload.done_at
  end

  it "does not tick an event that was cancelled, even by a hand-made request" do
    event = planner_items(:cancelled_event)
    event.update_columns(tracks_done: 1)
    patch planner_item_completion_path(event), params: {done: "1"}
    assert_nil event.reload.done_at
  end

  it "does not find another user's item" do
    patch planner_item_completion_path(planner_items(:other_users_event)), params: {done: "1"}
    assert_response :not_found
  end

  it "does not tick an abandoned task either" do
    task = planner_items(:abandoned_task)
    patch planner_item_completion_path(task), params: {done: "1"}
    assert_nil task.reload.done_at
  end

  it "says so when the item cannot be ticked any more, instead of doing nothing" do
    patch planner_item_completion_path(planner_items(:abandoned_task)), params: {done: "1"}
    assert_equal "That item cannot be ticked.", flash[:alert]
    patch planner_item_completion_path(planner_items(:holiday)), params: {done: "1"}
    assert_equal "That item cannot be ticked.", flash[:alert]
  end

  it "falls back to the page that lists the item's kind, not always the calendar" do
    patch planner_item_completion_path(planner_items(:buy_stamps_task)), params: {done: "1"}
    assert_redirected_to planner_schedule_path(date: "2026-10-08")
  end
end
