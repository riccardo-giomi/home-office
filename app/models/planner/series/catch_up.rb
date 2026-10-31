# Makes the past of a series into events.
#
# An occurrence whose day has passed becomes an event: unsaved occurrences exist
# only for today and later days. Only a series with `tracks_done` enabled is
# caught up this way, because users must be told about the deadlines they missed
# or the events they forgot to check. Any other series is not changed.
#
# `materialized_through` is the last day that was caught up. A change of the
# rule does not affect the days up to and including it.
#
# The new events are created in a single bulk insert, which keeps the cost low.
#
# What keeps the bulk insert safe is the unique index on the series and the date
# of the occurrence, and the transaction. `insert_all!` raises on a date that a
# concurrent request saved first. A plain `insert_all` would skip that row and
# leave its entity behind.
module Planner::Series::CatchUp
  extend ActiveSupport::Concern

  ITEM_COLUMNS = %w[
    user_id type title notes day starts_at ends_at time_zone tracks_done
    priority series_id occurrence_on
  ].freeze

  class_methods do
    # Catches up every series of the user that is not in the trash, has
    # `tracks_done` enabled and has days left to catch up. Returns the number of
    # events created.
    def catch_up(user, today:)
      owned_by(user).kept.where(tracks_done: 1).where(starts_on: ..(today - 1))
        .where("materialized_through IS NULL OR materialized_through < ?", today - 1)
        .sum { |series| series.catch_up(today - 1) }
    end
  end

  # Creates an event for each date of the rule up to and including `through`
  # that has no event and is not excluded, then sets `materialized_through` to
  # `through`. Returns the number of events created.
  def catch_up(through)
    first = [materialized_through&.next_day, starts_on, from_on].compact.max
    return 0 if first > through

    attempts = 0
    begin
      transaction(requires_new: true) do
        range = first..through
        skip = events.where(occurrence_on: range).pluck(:occurrence_on) +
          exclusions.where(excluded_on: range).pluck(:excluded_on)
        made = insert_occurrences(dates(range, skip:))
        # `update_columns` skips validations and leaves `lock_version`
        # unchanged. `update!` and `update_all` would increment it, and an open
        # edit form of this series would be refused as stale.
        update_columns(materialized_through: through)
        made
      end
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 2
      raise
    end
  end

  private

  def insert_occurrences(found)
    return 0 if found.empty?

    built = found.map { |date| build_occurrence(date) }
    stamp = Time.current
    entities = built.map do
      {user_id:, record_type: Planner::Item.base_class.name, created_at: stamp, updated_at: stamp}
    end
    ids = Core::Entity.insert_all!(entities, returning: %w[id]).rows.flatten
    last = Planner::Item.where(user_id:, type: Planner::Event.sti_name).maximum(:position).to_i
    rows = built.each_with_index.map do |event, index|
      event.attributes.slice(*ITEM_COLUMNS).merge(
        "id" => ids.fetch(index), "position" => last + index + 1,
        "created_at" => stamp, "updated_at" => stamp
      )
    end
    Planner::Item.insert_all!(rows)
    found.size
  end
end
