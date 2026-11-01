require "test_helper"
require_relative "shared_paged_agenda_list"

class Planner::ForgottenTasksControllerTest < ActionDispatch::IntegrationTest
  include SharedPagedAgendaList

  def list_path(**params) = planner_forgotten_tasks_path(**params)

  def page_title = "Forgotten tasks"

  def empty_text = "Nothing was forgotten."

  def late_item(day:, title:) = Planner::Task.create!(user: admin, title:, day:)

  def badge_text(count) = "#{count} forgotten tasks"

  def clear_items = Core::Entity.where(id: Planner::Task.where(user: admin).select(:id)).delete_all

  describe "what is forgotten" do
    before { sign_in_as admin }

    it "leaves out what is not late, not open or not a task" do
      get list_path
      titles = css_select("main a").map(&:text)
      # Late: Pay the rent (7 Oct), Buy stamps (8 Oct) and Renew the passport (5
      # Oct). The other fixtures are not
      assert_equal ["Renew the passport", "Pay the rent", "Buy stamps"], titles.grep(/passport|rent|stamps/)
      ["Call the bank", "Sort the attic", "Thrown away task", "Someone else's chore", "Water the plants", "Dentist"].each do |title|
        assert_select "main a", text: title, count: 0
      end
    end

    it "leaves out a todo that holds a day from before it was converted" do
      Planner::Todo.where(user: admin).first.update_columns(day: Date.new(2026, 9, 1))
      get list_path
      assert_select "main a", text: "Water the plants", count: 0
    end
  end

  describe "the Schedule" do
    before { sign_in_as admin }

    it "has a button to the list, with the count" do
      get planner_schedule_path
      assert_select "main a[href='#{list_path}']", text: /Forgotten tasks/ do
        assert_select "span.sr-only", text: "3 forgotten tasks"
      end
    end

    it "has no badge on the button when nothing was forgotten" do
      Planner::Task.where(user: admin).update_all(done_at: Time.current)
      get planner_schedule_path
      assert_select "main a[href='#{list_path}'] span.badge", count: 0
    end
  end
end
