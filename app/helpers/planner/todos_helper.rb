# The pieces of the todo list: a row's move buttons and words, and the entry a
# todo is drawn as.
module Planner::TodosHelper
  def todo_row(todo, first:, last:, moved_id:)
    {
      id: "todo_#{todo.id}",
      item_id: todo.id, move_url: planner_todo_position_path(todo),
      first:,
      last:,
      highlight: todo.id == moved_id,
      labels: %i[group up down top bottom].index_with do |key|
        t("planner.positions.labels.#{key}", title: todo.title)
      end
    }
  end

  # The same entry the calendar draws, without a time line (a todo has no moment
  # of its own).
  def todo_entry(todo)
    attributes = calendar_entry(todo)
    render(Core::UI::CalendarEntryComponent.new(**attributes.except(:check, :from, :to), show_time: false)) do |entry|
      entry.with_check { attributes[:check] } if attributes[:check]
    end
  end
end
