# The todo list: the pages every item has, plus the list in the order the user
# keeps.
class Planner::TodosController < Planner::ItemsController
  def index
    @todos = Planner::Todo.owned_by(Current.user).kept.in_order
    @moved_id = flash[:moved_id]
    @link_index = Core::LinkIndex.new(@todos.map(&:id))
  end

  private

  def item_class = Planner::Todo

  def initial_attributes = {}
end
