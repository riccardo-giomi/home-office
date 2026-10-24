# Takes an item out of the trash.
#
# The item is exactly as it was.
class Planner::RestorationsController < ApplicationController
  def update
    item = Planner::Item.owned_by(Current.user).trashed.includes(:entity).find(params[:item_id])
    item.restore
    redirect_to planner_trash_path(type: Planner::Trash.kind(params[:type])),
      notice: t(".restored", title: item.title),
      status: :see_other
  end
end
