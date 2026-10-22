require "test_helper"
require_relative "shared_item_pages"

class Planner::TasksControllerTest < ActionDispatch::IntegrationTest
  include SharedItemPages

  let(:item_class) { Planner::Task }
  let(:kind) { "task" }
  let(:sample) { planner_items(:pay_rent_task) }
  let(:all_day_sample) { planner_items(:buy_stamps_task) }
  let(:foreign) { planner_items(:other_users_task) }

  def default_back(task) = planner_schedule_path(date: task.day.iso8601)

  describe "what only tasks have" do
    before { sign_in_as admin }

    it "always tracks done, whatever the request says" do
      post planner_tasks_path, params: {planner_task: {title: "Pay", day: "2026-10-09", tracks_done: "0"}}
      assert_equal 1, Planner::Task.order(:id).last.tracks_done
    end

    it "has no field to switch the done checkbox off" do
      get new_planner_task_path
      assert_select "input[name='planner_task[tracks_done]']", 0
    end

    it "shows the done checkbox on every task" do
      get planner_task_path(planner_items(:buy_stamps_task))
      assert_select "input[type=checkbox][aria-label='Done: Buy stamps']", 1
    end

    it "names the schedule as the way back" do
      get planner_task_path(planner_items(:pay_rent_task))
      assert_select "a", text: "Back to schedule"
    end

    it "ticks a task in place" do
      patch planner_item_completion_path(planner_items(:buy_stamps_task)), params: {done: "1"}
      assert planner_items(:buy_stamps_task).reload.done?
    end
  end

  describe "the hint under the times" do
    before { sign_in_as admin }

    it "speaks of a task on the task form and of an event on the event form" do
      get new_planner_task_path
      assert_select "body", text: /all-day task/
      assert_select "body", text: /all-day event/, count: 0
      get new_planner_event_path
      assert_select "body", text: /all-day event/
    end
  end
end
