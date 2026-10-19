class Planner::CompletionsController < ApplicationController
  include Planner::EventPages

  def update
    event = Planner::Event.owned_by(Current.user).find(params[:event_id])
    if event.tracks_done?
      event.mark_done(params[:done] == "1")
      event.save!
      flash[:notice] = event.done? ? t(".done", title: event.title) : t(".not_done", title: event.title)
    end
    return redraw_dialog(event) if in_dialog?

    redirect_back_or_to planner_calendar_path, status: :see_other
  end

  private

  # Ticked in the dialog: the page behind refreshes, the details in the dialog are redrawn (morphed, so the
  # focus stays on the checkbox) and the dialog stays open
  def redraw_dialog(event)
    render turbo_stream: [
      turbo_stream.refresh(request_id: nil),
      turbo_stream.update(Planner::EventDialog::FRAME_ID, partial: "planner/events/show_content", locals: {event:}, method: :morph)
    ]
  end
end
