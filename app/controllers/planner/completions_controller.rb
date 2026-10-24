class Planner::CompletionsController < ApplicationController
  include Planner::ItemPages

  def update
    item = Planner::Item.owned_by(Current.user).kept.find(params[:item_id])
    if item.tracks_done? && item.active?
      item.mark_done(params[:done] == "1")
      item.save!
      flash[:notice] = item.done? ? t(".done", title: item.title) : t(".not_done", title: item.title)
    else
      flash[:alert] = t(".refused")
    end
    return redraw_dialog(item) if in_dialog?

    redirect_back_or_to default_back_path(item), status: :see_other
  end
end
