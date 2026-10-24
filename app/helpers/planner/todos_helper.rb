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
      end,
      actions: delete_todo(todo)
    }
  end

  # Delete button of a todo row.
  #
  # Every todo can be deleted, done or not. It goes to the trash.
  def delete_todo(todo)
    render(
      Core::UI::ModalComponent.new(
        id: "delete-todo-#{todo.id}",
        title: t("planner.kinds.todo.delete_title"),
        trigger_variant: :secondary,
        trigger_size: :xs,
        trigger: safe_join([t("planner.todos.index.delete_row"), tag.span(" #{todo.title}", class: "sr-only")])
      )
    ) do
      safe_join([
        tag.p(t("planner.kinds.todo.delete_warning", title: todo.title), class: "mb-4"),
        form_with(url: planner_todo_path(todo), method: :delete) do
          render(Core::UI::ButtonComponent.new(type: :submit, variant: :danger)) do
            t("planner.kinds.todo.delete_confirm")
          end
        end
      ])
    end
  end

  # Delete button of all the done todos.
  #
  # The list's one bulk action, after a confirmation that says how many.
  def delete_done_todos(count)
    render(
      Core::UI::ModalComponent.new(
        id: "delete-done-todos",
        title: t("planner.todos.index.delete_done_title"),
        trigger: t("planner.todos.index.delete_done")
      )
    ) do
      safe_join([
        tag.p(t("planner.todos.index.delete_done_warning", count:), class: "mb-4"),
        form_with(url: planner_done_todos_path, method: :delete) do
          render(Core::UI::ButtonComponent.new(type: :submit, variant: :danger)) do
            t("planner.todos.index.delete_done")
          end
        end
      ])
    end
  end

  # The same entry the calendar draws, without a time line (a todo has no moment
  # of its own).
  def todo_entry(todo)
    attributes = entry_attributes(todo)
    render(Core::UI::EntryComponent.new(**attributes.except(:check, :from, :to), show_time: false)) do |entry|
      entry.with_check { attributes[:check] } if attributes[:check]
    end
  end
end
