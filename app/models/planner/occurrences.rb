# What a calendar or an agenda shows for a range of days.
#
# The events of the user (rows) and the ghosts of their series, together. The
# number of queries is fixed, however many series there are.
module Planner::Occurrences
  def self.for(user, range)
    rows = Planner::Event.owned_by(user).kept.on_days(range).to_a
    series = Planner::Series.owned_by(user).kept.overlapping(range).to_a
    (rows + ghosts(series, range)).sort_by do |event|
      [event.day, event.starts_at ? 1 : 0, event.starts_at.to_i, event.id.to_i]
    end
  end

  def self.ghosts(series, range)
    return [] if series.empty?

    ids = series.map(&:id)
    excluded = Planner::SeriesExclusion.where(series_id: ids, excluded_on: range)
      .pluck(:series_id, :excluded_on).group_by(&:first)
    taken = Planner::Event.where(series_id: ids, occurrence_on: range)
      .pluck(:series_id, :occurrence_on).group_by(&:first)
    series.flat_map do |one|
      skip = (excluded.fetch(one.id, []) + taken.fetch(one.id, [])).map(&:last)
      one.dates(range, skip:).map { |date| one.build_occurrence(date) }
    end
  end
  private_class_method :ghosts
end
