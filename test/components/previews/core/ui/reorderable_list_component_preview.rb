class Core::UI::ReorderableListComponentPreview < ViewComponent::Preview
  TITLES = ["Water the plants", "Call mom", "Finish the book", "Renew the license"].freeze

  def default = render(list(TITLES, prefix: "default"))

  # The row that was just moved is tinted for two seconds, then fades back:
  # reload to see it again.
  def just_moved = render(list(TITLES, prefix: "moved", highlight: 1))

  # What the todo list shows: a button after the move buttons, which opens its
  # confirmation.
  def with_delete = render(list(TITLES, prefix: "delete", delete: true))

  def one_row = render(list(["Water the plants"], prefix: "one"))

  def long_title = render(list(["A" * 120, "Short"], prefix: "long"))

  def empty = render(list([], prefix: "none"))

  private

  # The Theme page shows every example at once, so no id may repeat between
  # them: each has its own prefix.
  def list(titles, prefix:, highlight: nil, delete: false)
    Core::UI::ReorderableListComponent.new(label: "Todo list", empty_text: "No todos. Add the first one.").tap do |component|
      titles.each_with_index do |title, index|
        component.with_row(id: "#{prefix}_todo_#{index}", item_id: index + 1, move_url: "#", first: index.zero?, last: index == titles.size - 1, highlight: index == highlight,
          actions: (delete_button("#{prefix}_delete_#{index}", title) if delete),
          labels: {group: "Move #{title}", up: "Move up: #{title}", down: "Move down: #{title}", top: "Move to top: #{title}", bottom: "Move to bottom: #{title}"}) do
          entry(title)
        end
      end
    end
  end

  # The trigger says "Remove row" and not "Delete". The Theme page shows every
  # preview at once, and its tests look for the one button named Delete.
  def delete_button(id, title)
    ApplicationController.render(Core::UI::ModalComponent.new(id:, title: "Delete this todo?", trigger: "Remove row", trigger_size: :xs), layout: false) { "“#{title}” goes to the trash.".html_safe }.html_safe
  end

  # `render` inside a preview builds a preview request, so slot content is
  # rendered to a string here.
  def entry(title) = ApplicationController.render(Core::UI::EntryComponent.new(title:, href: "#", show_time: false, statuses: [{priority: :high, label: "High priority"}]), layout: false).html_safe
end
