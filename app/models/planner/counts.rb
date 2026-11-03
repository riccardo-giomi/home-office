# The numbers shown by the sidebar badges and the dashboard cards.
#
# `Planner::Counts.for` returns one instance for each user and request, and each
# number is queried at most once.
#
# Only records of the user that are not in the trash are counted. "Today" is the
# date in the time zone of the user and the week starts on the first weekday of
# the user. The request sets both before the first call.
class Planner::Counts
  def self.for(user)
    Current.counts ||= {}
    Current.counts[user.id] ||= new(user, today: Date.current, first_weekday: Current.first_weekday || 1)
  end

  def self.reset = (Current.counts = nil)

  def initialize(user, today:, first_weekday:)
    @user = user
    @today = today
    @weekday = Planner::Calendar::Period::WEEKDAYS.fetch(first_weekday)
  end

  def important = (@important ||= Planner::ImportantEvents.new(@user, today: @today).count)

  def missed = (@missed ||= Planner::Event.owned_by(@user).missed(@today).count)

  def forgotten = (@forgotten ||= Planner::Task.owned_by(@user).forgotten(@today).count)

  def events_today = (@events_today ||= events_on(@today..@today))

  def events_week = (@events_week ||= events_on(week))

  def tasks_today = (@tasks_today ||= open_tasks.where(day: @today).count)

  def tasks_week = (@tasks_week ||= open_tasks.where(day: week).count)

  def todos = (@todos ||= open_todos.count)

  def todos_urgent = (@todos_urgent ||= open_todos.where(priority: "urgent").count)

  private

  def week = @today.beginning_of_week(@weekday)..@today.end_of_week(@weekday)

  # Counts the active events in the range, done or not. The unsaved occurrences
  # of series are included.
  def events_on(range) = Planner::Occurrences.for(@user, range).count(&:active?)

  def open_tasks = Planner::Task.owned_by(@user).kept.where(state: "active", done_at: nil)

  def open_todos = Planner::Todo.owned_by(@user).kept.where(state: "active", done_at: nil)
end
