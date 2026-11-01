# The trash of the Planner.
#
# Every trashed item, all kinds together or one kind, to restore or to empty for
# good.
class Planner::TrashesController < ApplicationController
  include Core::Paginated

  def show
    @trash = Planner::Trash.new(Current.user, type: params[:type])
    @pagy, @items = paginate(@trash.items, type: @trash.type)
  end

  def destroy
    count = Planner::Trash.new(Current.user).empty!
    redirect_to planner_trash_path, notice: t(".emptied", count:), status: :see_other
  end
end
