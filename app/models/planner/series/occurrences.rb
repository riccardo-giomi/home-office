# The occurrences of a series.
#
# A date is a ghost until someone touches it: an occurrence that exists only
# as an unsaved event built from the template. `materialize` makes one real,
# once, however many requests ask at the same time.
#
# A date that has a row (in any state, trashed included) or a skip is never an
# unsaved occurrence. A row keeps the date the rule gave it (`occurrence_on`)
# when it moves, so its old date does not become an unsaved occurrence again.
module Planner::Series::Occurrences
  extend ActiveSupport::Concern

  included do
    scope :overlapping, ->(range) do
      where(starts_on: ..range.last).where("planner_series.ends_on IS NULL OR planner_series.ends_on >= ?", range.first)
    end
  end

  # The dates the rule gives inside `range` and the visible span, less the
  # skipped ones.
  #
  # `skip`, a list of dates, spares the two queries that find them when the
  # caller asked for many series at once.
  def dates(range, skip: nil)
    window = [range.first, starts_on, from_on].compact.max..[range.last, ends_on].compact.min
    return [] if window.first > window.last

    found = Planner::Recurrence::Expander.dates(rrule:, starts_on:, start_time:, time_zone:, between: window)
    found - (skip || skipped(found))
  end

  # The dates in `range` that are unsaved occurrences: dates of the rule after
  # `materialized_through` that have no event and are not excluded.
  #
  # A date up to and including `materialized_through` that has no event is not
  # an occurrence: a change of the rule moved it away, or it was deleted.
  def unsaved_dates(range, skip: nil)
    range = [range.first, materialized_through&.next_day].compact.max..range.last
    (range.first > range.last) ? [] : dates(range, skip:)
  end

  # An unsaved event, as it would be if the date were touched now.
  def build_occurrence(date)
    event = Planner::Event.new(user_id:, series: self, occurrence_on: date, day: date, title:, notes:, priority:, tracks_done:)
    if start_time
      starts = ActiveSupport::TimeZone[time_zone].parse("#{date} #{start_time}")
      event.assign_attributes(starts_at: starts.utc, ends_at: (starts + duration_minutes.minutes).utc, time_zone:)
    end
    event
  end

  # The row for the date, else an unsaved occurrence, else nil (the rule does
  # not give the date, or it is skipped).
  def occurrence(date)
    events.includes(:entity).find_by(occurrence_on: date) || (build_occurrence(date) if unsaved_dates(date..date).any?)
  end

  # The row for the date, made now if it was unsaved.
  #
  # Safe to call twice at once: the call that lost reads the winner.
  def materialize(date)
    found = occurrence(date) or raise ActiveRecord::RecordNotFound, "#{date} is not an occurrence of series #{id}"
    return found if found.persisted?

    found.save!
    found
  rescue ActiveRecord::RecordNotUnique
    events.includes(:entity).find_by!(occurrence_on: date)
  end

  private

  def skipped(found)
    exclusions.where(excluded_on: found).pluck(:excluded_on) + events.where(occurrence_on: found).pluck(:occurrence_on)
  end
end
