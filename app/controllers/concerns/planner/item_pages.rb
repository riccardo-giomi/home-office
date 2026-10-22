# What the item pages and the completion and state routes share: whether they
# were asked from the dialog of the calendar, the agenda and the schedule, and
# where a visit that began on one of those pages should return to.
module Planner::ItemPages
  extend ActiveSupport::Concern

  included do
    helper_method :in_dialog?, :back_location, :back_param, :default_back_page, :default_back_path
  end

  private

  # A frame request from the dialog: the page is shown over the calendar, which
  # stays as it was.
  def in_dialog? = turbo_frame_request_id == Planner::ItemDialog::FRAME_ID

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
    render turbo_stream: [turbo_stream.refresh(request_id: nil), turbo_stream.action(:close_dialog, Planner::ItemDialog::ID)]
  end

  # The page behind refreshes and the details inside the dialog are redrawn
  # (morphed, so the focus stays on the control just used); the dialog stays
  # open. For changes made to an item that is being looked at.
  def redraw_dialog(item)
    render turbo_stream: [
      turbo_stream.refresh(request_id: nil),
      turbo_stream.update(Planner::ItemDialog::FRAME_ID, partial: "planner/items/show_content", locals: {item:}, method: :morph)
    ]
  end

  # Where "Back" goes when the visit did not begin on one of the listing pages:
  # the page that lists this kind of item, around the item's day.
  def default_back_page(item) = item.class.listing_page

  def default_back_path(item) = public_send(:"planner_#{default_back_page(item)}_path", date: item.day&.iso8601)
end
