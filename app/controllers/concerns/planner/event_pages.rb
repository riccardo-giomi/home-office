# What the event pages and the completion route share: whether they were asked
# from the dialog of the calendar and the agenda, and where a visit that began on
# one of those pages should return to.
module Planner::EventPages
  extend ActiveSupport::Concern

  included do
    helper_method :in_dialog?, :back_location, :back_param
  end

  private

  # A frame request from the dialog: the page is shown over the calendar, which
  # stays as it was.
  def in_dialog? = turbo_frame_request_id == Planner::EventDialog::FRAME_ID

  # The calendar or agenda page a full-page visit began on, when it says so and
  # the address is one of ours.
  def back_location = @back_location ||= Planner::BackLocation.parse(params[:back])

  # What to put in links and forms so the next page knows too: nothing when
  # there is nothing to carry.
  def back_param = back_location&.path

  # A change made in the dialog: the page behind refreshes (by morphing, so its
  # scroll and view stay), the dialog closes, and the notice shows after the
  # refresh.
  def dialog_done(notice)
    flash[:notice] = notice
    render turbo_stream: [turbo_stream.refresh(request_id: nil), turbo_stream.action(:close_dialog, Planner::EventDialog::ID)]
  end
end
