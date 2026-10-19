# What the event pages and the completion route share: where a visit that began
# on the calendar or the agenda should return to.
module Planner::EventPages
  extend ActiveSupport::Concern

  included do
    helper_method :back_location, :back_param
  end

  private

  # The calendar or agenda page a full-page visit began on, when it says so and
  # the address is one of ours.
  def back_location = @back_location ||= Planner::BackLocation.parse(params[:back])

  # What to put in links and forms so the next page knows too: nothing when
  # there is nothing to carry.
  def back_param = back_location&.path
end
