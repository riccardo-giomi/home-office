require "test_helper"

class Planner::DoneTodosControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(locale: "en")
    sign_in_as admin
  end

  it "sends anonymous visitors to sign in" do
    sign_out
    delete planner_done_todos_path
    assert_redirected_to new_session_path
    assert_nil planner_items(:read_book_todo).reload.deleted_at
  end

  it "moves every done todo of the user to the trash, and nothing else" do
    task = planner_items(:done_task)
    event = planner_items(:rent_paid)
    foreign = planner_items(:other_users_todo)
    foreign.update_columns(done_at: Time.current)
    delete planner_done_todos_path
    assert_redirected_to planner_todos_path
    assert_equal "1 done todo moved to the trash.", flash[:notice]
    assert_predicate planner_items(:read_book_todo).reload, :trashed?
    [planner_items(:water_plants_todo), planner_items(:call_mom_todo), task, event, foreign].each { |item| refute_predicate item.reload, :trashed? }
  end

  it "counts them in the notice" do
    planner_items(:call_mom_todo).update_columns(done_at: Time.current)
    delete planner_done_todos_path
    assert_equal "2 done todos moved to the trash.", flash[:notice]
  end

  it "says so when there is nothing to delete" do
    Planner::Todo.owned_by(admin).update_all(done_at: nil)
    delete planner_done_todos_path
    assert_redirected_to planner_todos_path
    assert_equal "No done todos to delete.", flash[:notice]
  end

  it "leaves already trashed todos at their time" do
    gone = planner_items(:trashed_todo)
    gone.update_columns(done_at: Time.current)
    gone.entity.update_columns(deleted_at: 3.days.ago)
    before = gone.reload.deleted_at
    delete planner_done_todos_path
    assert_equal before, gone.reload.deleted_at
  end

  it "says in Italian too" do
    admin.update!(locale: "it")
    delete planner_done_todos_path
    assert_equal "1 da fare completato spostato nel cestino.", flash[:notice]
  end
end
