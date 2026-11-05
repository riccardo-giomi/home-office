# The part of the Planner in the MCP overview.
#
# What needs a look today, as short lists. Empty ones are left out.
module Planner::Mcp::Overview
  LIST_SIZE = 10

  def self.call(user, today)
    {
      today: list(dated_today(user, today)),
      important: list(Planner::ImportantEvents.new(user, today:).entries),
      missed: list(Planner::Event.owned_by(user).missed(today).order(:day, :starts_at, :id).to_a),
      forgotten: list(Planner::Task.owned_by(user).forgotten(today).order(:day, :starts_at, :id).to_a)
    }.compact
  end

  # The events of the day (unsaved occurrences too) and the tasks still to do,
  # by time.
  def self.dated_today(user, today)
    events = Planner::Occurrences.for(user, today..today).select(&:active?)
    tasks = Planner::Task.owned_by(user).kept.where(day: today, state: "active", done_at: nil).to_a
    Planner::Occurrences.chronological(events + tasks)
  end

  def self.list(items)
    return if items.empty?

    {total: items.size, items: items.first(LIST_SIZE).map { |item| Planner::Mcp::ItemPresenter.new(item).to_h }}
  end
end
