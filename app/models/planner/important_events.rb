# The events that matter in the days ahead: events with priority urgent (minimum
# `urgent`) or urgent and high (minimum `high`), from today to the last day of
# the horizon, earliest first.
#
# A series appears once, as its nearest occurrence that is not done. Saved
# events come from the database and unsaved occurrences are built from the rule,
# so this class never saves an occurrence.
class Planner::ImportantEvents
  HORIZONS = %w[7d 30d 6m 1y].freeze
  MINIMUMS = {"urgent" => %w[urgent], "high" => %w[urgent high]}.freeze

  attr_reader :horizon, :minimum

  # An unknown horizon or minimum falls back to the default (the first of
  # HORIZONS and of MINIMUMS), so an old address does not break the page.
  def initialize(user, today:, horizon: nil, minimum: nil)
    @user = user
    @today = today
    @horizon = horizon.presence_in(HORIZONS) || HORIZONS.first
    @minimum = minimum.presence_in(MINIMUMS.keys) || MINIMUMS.keys.first
  end

  # From today to the last day of the horizon.
  def range = @today..last_day

  # Returns the events in the range, earliest first. The unsaved occurrences of
  # series are included.
  def entries
    @entries ||= begin
      nearest = (events + unsaved_occurrences)
        .group_by { |event| event.series_id ? [:series, event.series_id] : [:event, event.id] }
        .values.map { |group| Planner::Occurrences.chronological(group).first }
      Planner::Occurrences.chronological(nearest)
    end
  end

  def count = entries.size

  private

  def last_day
    case horizon
    when "7d" then @today + 6
    when "30d" then @today + 29
    when "6m" then @today.advance(months: 6) - 1
    else @today.advance(years: 1) - 1
    end
  end

  def levels = MINIMUMS.fetch(minimum)

  # Returns the saved events in the range that have the minimum priority, only
  # the first of each series by day. An event that is not in a series counts as
  # a series of its own.
  def events
    wanted = Planner::Event.owned_by(@user).kept
      .where(state: "active", done_at: nil, priority: levels, day: range)
    ranked = wanted.select(<<~SQL.squish)
      planner_items.id AS id,
      ROW_NUMBER() OVER (
        PARTITION BY COALESCE(planner_items.series_id, -planner_items.id)
        ORDER BY planner_items.day, planner_items.starts_at
      ) AS n
    SQL
    ids = Planner::Event.connection.select_values("SELECT id FROM (#{ranked.to_sql}) WHERE n = 1")
    Planner::Event.where(id: ids).to_a
  end

  # Returns the unsaved occurrences in the range of the series whose own
  # priority meets the minimum.
  def unsaved_occurrences
    series = Planner::Series.owned_by(@user).kept.where(priority: levels).overlapping(range).to_a
    Planner::Occurrences.unsaved_occurrences(series, range)
  end
end
