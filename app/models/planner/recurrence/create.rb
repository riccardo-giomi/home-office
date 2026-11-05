# Makes a series from an event that repeats.
#
# The event is only the template: it is never saved, and its first occurrence
# is unsaved like the others. It sits beside Edit and Delete, so the pages and
# the MCP tools make series the same way.
class Planner::Recurrence::Create
  # event: an unsaved Planner::Event. form: the Planner::Recurrence::Form with
  # the repeat fields.
  def initialize(event:, form:)
    @event = event
    @form = form
  end

  # Returns the saved series, or false with the reasons in the errors of the
  # event (and of the form, for the rule).
  def call
    @event.validate
    rule = @form.rule_for(@event.day) if @event.day
    return false unless @event.errors.empty? && rule

    series = Planner::Series.from_event(@event, rule)
    return series if series.save(context: :entry)

    series.errors.each do |error|
      if error.attribute == :starts_on
        @event.errors.add(:day, error.message)
      else
        @event.errors.add(:base, error.full_message)
      end
    end
    false
  end
end
