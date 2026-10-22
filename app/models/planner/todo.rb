# A thing to do with no moment of its own, kept in the order the user chooses.
#
# A todo may still carry a day and times: an event or task turned into one
# keeps them, so turning it back loses nothing. Its pages never show them.
class Planner::Todo < Planner::Item
  include Planner::AlwaysDone

  # The page that lists it, where "Back" goes by default.
  def self.listing_page = :todos

  # Important ones go to the top of the list, the rest to the bottom. Changing
  # the priority later never moves it.
  before_validation :place_by_priority, on: :create

  scope :in_order, -> { order(:position) }

  def timed? = false

  # Moves the todo within its user's list. `where` is :up, :down, :top, :bottom,
  # {before: todo} or {after: todo}. Returns false when nothing moves.
  #
  # The neighbors are read from the database, not from this record, so a page
  # that has gone stale cannot scramble the order.
  def move(where)
    list = self.class.where(user_id:).in_order.to_a
    index = list.index { |todo| todo.id == id }
    target = index && destination(where, list, index)
    target ? update!(position: target) : false
  end

  private

  def destination(where, list, index)
    case where
    in :up then index.positive? && {before: list[index - 1]}
    in :down then list[index + 1] && {after: list[index + 1]}
    in :top then index.positive? && :first
    in :bottom then index < list.size - 1 && :last
    in Hash if where.size == 1 && where.keys.first.in?(%i[before after])
      other = where.values.first
      other.is_a?(Planner::Todo) && other.id != id && list.any? { |todo| todo.id == other.id } && where
    else false
    end
  end

  def place_by_priority = (self.position ||= (high? || urgent?) ? :first : :last)

  # No abandoning: a todo that is no longer wanted is deleted.
  def can_change_state_to?(_) = false
end
