# The numbers shown by the sidebar badges and the dashboard cards.
# `Planner::Counts.for` returns one instance for each user and request, and each
# number is queried at most once.
#
# Only records of the user that are not in the trash are counted. "Today" is the
# date in the time zone of the user and the week starts on the first weekday of
# the user. The request sets both before the first call.
class Planner::Counts
  def self.for(user)
    Current.counts ||= {}
    Current.counts[user.id] ||= new(user, today: Date.current)
  end

  def self.reset = (Current.counts = nil)

  def initialize(user, today:)
    @user = user
    @today = today
  end

  def forgotten = (@forgotten ||= Planner::Task.owned_by(@user).forgotten(@today).count)
end
