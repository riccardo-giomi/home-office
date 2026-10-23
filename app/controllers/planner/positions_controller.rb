# Moves a todo in the user's list, by a button (`move`: up, down, top, bottom) or
# by a drop (`after` or `before`: the todo it now sits next to).
#
# The rules are the model's (Todo#move); this reports what happened, and keeps
# the id of the todo that moved for the page to highlight.
class Planner::PositionsController < ApplicationController
  MOVES = %w[up down top bottom].freeze

  def update
    todo = Planner::Todo.owned_by(Current.user).find(params[:todo_id])
    move = requested_move
    if move.nil?
      flash[:alert] = t(".refused")
    elsif todo.move(move)
      flash[:notice] = t(".moved", title: todo.title, position: todo.position, count: Planner::Todo.owned_by(Current.user).count)
      flash[:moved_id] = todo.id
    else
      flash[:alert] = t(".unchanged", title: todo.title)
    end
    redirect_to planner_todos_path, status: :see_other
  end

  private

  # Returns the move asked for: a symbol (:up), a hash ({after: todo}) or nil
  # when the request is not exactly one valid move. A neighbor must be one of
  # the user's own todos.
  def requested_move
    given = params.permit(:move, :after, :before).to_h.compact_blank
    return unless given.size == 1

    key, value = given.first
    return MOVES.include?(value) ? value.to_sym : nil if key == "move"

    neighbor = Planner::Todo.owned_by(Current.user).find_by(id: value)
    {key.to_sym => neighbor} if neighbor
  end
end
