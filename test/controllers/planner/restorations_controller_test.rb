require "test_helper"

class Planner::RestorationsControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(locale: "en")
    sign_in_as admin
  end

  it "sends anonymous visitors to sign in" do
    sign_out
    patch planner_item_restoration_path(planner_items(:trashed_event))
    assert_redirected_to new_session_path
    assert_predicate planner_items(:trashed_event).reload, :trashed?
  end

  it "restores an item exactly as it was and returns to the trash with a notice" do
    todo = planner_items(:trashed_todo)
    position = todo.position
    patch planner_item_restoration_path(todo)
    assert_redirected_to planner_trash_path
    assert_equal "“Thrown away todo” restored.", flash[:notice]
    todo.reload
    refute_predicate todo, :trashed?
    assert_equal position, todo.position
    assert_includes Planner::Todo.owned_by(admin).kept.in_order, todo
  end

  it "keeps the tab it was asked from" do
    patch planner_item_restoration_path(planner_items(:trashed_task)), params: {type: "task"}
    assert_redirected_to planner_trash_path(type: "task")
  end

  it "does not find another user's trashed item, or an item that is not in the trash" do
    patch planner_item_restoration_path(planner_items(:other_users_trashed_event))
    assert_response :not_found
    assert_predicate planner_items(:other_users_trashed_event).reload, :trashed?
    patch planner_item_restoration_path(planner_items(:dentist))
    assert_response :not_found
  end

  it "says it in Italian" do
    admin.update!(locale: "it")
    patch planner_item_restoration_path(planner_items(:trashed_event))
    assert_equal "«Thrown away event» ripristinato.", flash[:notice]
  end
end
