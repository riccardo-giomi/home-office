# Lists the tasks that are dated before today and still open. From the list, a
# task can be marked done, given a new day or abandoned.
class Planner::ForgottenTasksController < ApplicationController
  include Planner::PagedAgendaList

  private

  def items = Planner::Task.owned_by(Current.user).forgotten(Date.current)

  def back_path = planner_schedule_path
end
