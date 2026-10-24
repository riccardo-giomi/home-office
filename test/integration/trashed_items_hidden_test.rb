require "test_helper"

# Trashed items are out of reach.
#
# They stay out of every page and cannot be changed. Only the trash can show and
# restore them.
class TrashedItemsHiddenTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    travel_to Time.utc(2026, 10, 7, 12)
    admin.update!(locale: "en")
    sign_in_as admin
  end

  {
    "the calendar" => [-> { planner_calendar_path(date: "2026-10-07", view: "day") }, "Thrown away event", "Dentist"],
    "the agenda" => [-> { planner_agenda_path(date: "2026-10-07", view: "day") }, "Thrown away event", "Dentist"],
    "the schedule" => [-> { planner_schedule_path(date: "2026-09-30", view: "week") }, "Thrown away task", "Sort the attic"],
    "the todo list" => [-> { planner_todos_path }, "Thrown away todo", "Water the plants"]
  }.each do |page, (path, trashed, kept)|
    it "keeps trashed items off #{page}" do
      get instance_exec(&path)
      assert_response :success
      assert_includes response.body, kept
      refute_includes response.body, trashed
    end
  end

  it "does not find a trashed item to show, edit, update, delete, tick or change" do
    {event: :trashed_event, task: :trashed_task, todo: :trashed_todo}.each do |kind, name|
      item = planner_items(name)
      get public_send(:"planner_#{kind}_path", item)
      assert_response :not_found
      get public_send(:"edit_planner_#{kind}_path", item)
      assert_response :not_found
      patch public_send(:"planner_#{kind}_path", item), params: {kind => {title: "Changed"}}
      assert_response :not_found
      delete public_send(:"planner_#{kind}_path", item)
      assert_response :not_found
      patch planner_item_completion_path(item), params: {done: "1"}
      assert_response :not_found
      patch planner_item_state_path(item), params: {state: "abandoned"}
      assert_response :not_found
      assert_equal "Thrown away #{kind}", item.reload.title
      assert_nil item.done_at
    end
  end

  it "does not move a trashed todo, or a todo next to a trashed one" do
    trashed = planner_items(:trashed_todo)
    patch planner_todo_position_path(trashed), params: {move: "top"}
    assert_response :not_found
    patch planner_todo_position_path(planner_items(:call_mom_todo)), params: {after: trashed.id}
    assert_redirected_to planner_todos_path
    assert_equal I18n.t("planner.positions.update.refused"), flash[:alert]
  end
end
