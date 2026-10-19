class Planner::CompletionsController < ApplicationController
  def update
    event = Planner::Event.owned_by(Current.user).find(params[:event_id])
    if event.tracks_done?
      event.mark_done(params[:done] == "1")
      event.save!
      flash[:notice] = event.done? ? t(".done", title: event.title) : t(".not_done", title: event.title)
    end
    redirect_back_or_to planner_calendar_path, status: :see_other
  end
end
