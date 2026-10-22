# Moves a todo in the user's list.
#
# The rules are the model's (Todo#move); this reports what happened, and keeps
# the id of the todo that moved for the page to highlight.
class Planner::PositionsController < ApplicationController
  MOVES = %w[up down top bottom].freeze

  def update
    todo = Planner::Todo.owned_by(Current.user).find(params[:todo_id])
    if MOVES.exclude?(params[:move].to_s)
      flash[:alert] = t(".refused")
    elsif todo.move(params[:move].to_sym)
      flash[:notice] = t(".moved", title: todo.title, position: todo.position, count: Planner::Todo.owned_by(Current.user).count)
      flash[:moved_id] = todo.id
    else
      flash[:alert] = t(".unchanged", title: todo.title)
    end
    redirect_to planner_todos_path, status: :see_other
  end
end
