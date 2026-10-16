# A checkbox with no visible label of its own (a row's "done" checker), the
# name comes from aria-label.
# Round: a circle that fills with a check says "done", where a square box looks
# like a selection (the rows will also have a Select button or other control).
class Core::UI::CheckboxComponent < ApplicationComponent
  def initialize(name:, checked:, label:, **html_options)
    @name = name
    @checked = checked
    @label = label
    @html_options = html_options
  end

  def call
    tag.input(type: :checkbox, name: @name, value: 1, checked: @checked, "aria-label": @label, class: "checkbox rounded-full", **@html_options)
  end
end
