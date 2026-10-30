# Takes an item, or a whole series, out of the trash.
#
# What comes out is exactly as it was.
class Planner::RestorationsController < ApplicationController
  def update
    title = request.path_parameters.key?(:series_id) ? restore_series : restore_item
    redirect_to planner_trash_path(type: Planner::Trash.kind(params[:type])),
      notice: t(".restored", title:),
      status: :see_other
  end

  private

  def restore_item
    item = Planner::Item.owned_by(Current.user).trashed.includes(:entity)
      .find(request.path_parameters[:item_id])
    item.restore
    item.title
  end

  # With what went to the trash together with it.
  def restore_series
    series = Planner::Series.owned_by(Current.user).trashed.find(request.path_parameters[:series_id])
    series.restore_group
    series.title
  end
end
