# Serves the event pages (show, edit, update) for an event that may not exist
# yet.
#
# An occurrence is saved as an event when an update on it makes its existence as
# a distinct record important.
#
# Note that other controllers can also materialize an occurrence: when it is
# marked as "done" in CompletionsController for example.
class Planner::OccurrencesController < Planner::EventsController
  def update
    super
  rescue ActiveRecord::RecordNotUnique
    # Another request saved this occurrence first: the change goes to that one.
    @item = @item.series.occurrence(@item.occurrence_on)
    super
  end

  private

  # One occurrence of a series, named by the series and the date the rule gave
  # it.
  def set_item
    @item = Planner::ItemRef.find(Current.user, series_id: params[:series_id], on: Date.iso8601(params[:on])) ||
      raise(ActiveRecord::RecordNotFound)
  rescue Date::Error
    raise ActiveRecord::RecordNotFound
  end
end
