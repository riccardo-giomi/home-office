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

  describe "a series" do
    let(:gym) do
      Planner::Series.create!(user: admin, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "UTC", rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60)
    end

    before do
      gym.materialize(Date.new(2026, 10, 12))
      Planner::Recurrence::Delete.new(series: gym, item: gym.occurrence(Date.new(2026, 10, 19)), scope: "all").call
    end

    it "is restored with the events that went with it, and the user goes back to the trash with a notice" do
      patch planner_series_restoration_path(gym)
      assert_redirected_to planner_trash_path
      assert_equal "“Gym” restored.", flash[:notice]
      assert_nil gym.reload.deleted_at
      assert_equal [false], Planner::Event.includes(:entity).where(series_id: gym.id).map(&:trashed?)
    end

    it "keeps the tab it was asked from" do
      patch planner_series_restoration_path(gym), params: {type: "event"}
      assert_redirected_to planner_trash_path(type: "event")
    end

    it "is not found when it is not in the trash, is another user's, or does not exist" do
      theirs = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 5), time_zone: "UTC", rrule: "FREQ=DAILY")
      Planner::Series.where(id: theirs.id).update_all(deleted_at: Time.current)
      patch planner_series_restoration_path(theirs)
      assert_response :not_found
      assert_predicate theirs.reload, :trashed?
      gym.reload.restore_group
      patch planner_series_restoration_path(gym)
      assert_response :not_found
      patch planner_series_restoration_path(0)
      assert_response :not_found
    end

    it "sends anonymous visitors to sign in" do
      sign_out
      patch planner_series_restoration_path(gym)
      assert_redirected_to new_session_path
      assert_predicate gym.reload, :trashed?
    end
  end
end
