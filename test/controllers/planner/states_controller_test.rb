require "test_helper"

class Planner::StatesControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }
  let(:task) { planner_items(:pay_rent_task) }
  let(:event) { planner_items(:dentist) }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 5, 12)
    sign_in_as admin
  end

  it "abandons a task and says so" do
    patch planner_item_state_path(task), params: {state: "abandoned"}
    assert_redirected_to planner_task_path(task)
    assert_equal "abandoned", task.reload.state
    assert_equal "Task abandoned.", flash[:notice]
  end

  it "abandons and cancels an event" do
    patch planner_item_state_path(event), params: {state: "cancelled"}
    assert_equal "cancelled", event.reload.state
    assert_equal "Event cancelled.", flash[:notice]
    patch planner_item_state_path(event), params: {state: "active"}
    assert_equal "Event reopened.", flash[:notice]
    patch planner_item_state_path(event), params: {state: "abandoned"}
    assert_equal "abandoned", event.reload.state
  end

  it "reopens an abandoned task" do
    patch planner_item_state_path(planner_items(:abandoned_task)), params: {state: "active"}
    assert_equal "active", planner_items(:abandoned_task).reload.state
  end

  it "carries the back address on to the item page" do
    back = planner_agenda_path(view: "week", date: "2026-10-07")
    patch planner_item_state_path(event), params: {state: "abandoned", back:}
    assert_redirected_to planner_event_path(event, back:)
  end

  it "refuses what cannot happen, changing nothing: canceling a task, junk, reopening an active item, a replaced item" do
    [[task, "cancelled"], [task, "banana"], [task, ""], [event, "active"]].each do |item, state|
      patch planner_item_state_path(item), params: {state:}
      assert_redirected_to polymorphic_path(item), state
      assert_equal "That change is not possible.", flash[:alert]
      assert_equal "active", item.reload.state
    end
  end

  it "refuses an item that was already changed elsewhere, without an error" do
    patch planner_item_state_path(task), params: {state: "abandoned"}
    patch planner_item_state_path(task), params: {state: "abandoned"}
    assert_response :see_other
    assert_equal "That change is not possible.", flash[:alert]
  end

  it "does not find another user's item" do
    patch planner_item_state_path(planner_items(:other_users_task)), params: {state: "abandoned"}
    assert_response :not_found
    assert_equal "active", planner_items(:other_users_task).reload.state
  end

  it "in the dialog refreshes the page behind and redraws the details, keeping the dialog open" do
    patch planner_item_state_path(task), headers: {"Turbo-Frame" => "item-dialog-frame"}, params: {state: "abandoned"}
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=refresh]:not([request-id])", 1
    assert_select "turbo-stream[action=update][target=item-dialog-frame][method=morph]", 1
    assert_select "turbo-stream[action=update] template", text: /Abandoned/
    assert_select "turbo-stream[action=close_dialog]", 0
  end

  it "makes anonymous visitors sign in" do
    sign_out
    patch planner_item_state_path(task), params: {state: "abandoned"}
    assert_redirected_to new_session_path
  end
end
