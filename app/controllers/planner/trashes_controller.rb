# The trash of the Planner.
#
# Every trashed item, all kinds together or one kind, to restore or to empty for
# good.
class Planner::TrashesController < ApplicationController
  include Pagy::Method

  def show
    @trash = Planner::Trash.new(Current.user, type: params[:type])
    @pagy, @items = pagy(:offset, @trash.items, limit: 25)
    # An old address can name a page that is gone (items restored since). Go to
    # the last one, not to an empty list.
    if @items.empty? && @pagy.page > @pagy.last
      redirect_to planner_trash_path(type: @trash.type, page: @pagy.last)
    end
  end

  def destroy
    count = Planner::Trash.new(Current.user).empty!
    redirect_to planner_trash_path, notice: t(".emptied", count:), status: :see_other
  end
end
