# Trash of all the done todos.
#
# Sends every done todo of the user to the trash at once. Todos keep no history,
# so done ones are cleared this way.
class Planner::DoneTodosController < ApplicationController
  def destroy
    done = Planner::Todo.owned_by(Current.user).kept.where.not(done_at: nil)
    # One statement over the entities of those todos. It is the one place where
    # `trash` is not called for each record.
    count = Core::Entity.where(id: done.select(:id)).update_all(deleted_at: Time.current)
    redirect_to planner_todos_path, notice: t(".deleted", count:), status: :see_other
  end
end
