require "application_system_test_case"
require_relative "paged_agenda_list_examples"

class Planner::ForgottenTasksSystemTest < ApplicationSystemTestCase
  include PagedAgendaListExamples

  def list_path(**params) = planner_forgotten_tasks_path(**params)

  def controller_kind = "forgotten_tasks"

  def item_kind = "task"

  def late_item(title, days_ago) = Planner::Task.create!(user: admin, title:, day: Date.current - days_ago)

  def clear_items = Core::Entity.where(id: Planner::Task.where(user: admin).select(:id)).delete_all

  def abandon_label = I18n.t("planner.kinds.task.abandon")

  it "is reached from the Schedule, which counts what was forgotten" do
    late_item("Stale", 2)
    sign_in_through_form admin
    visit planner_schedule_path
    within("main") { click_link(href: list_path) }
    assert_selector "h1", text: "Forgotten tasks"
    assert_selector "main li a", text: "Stale"
  end
end
