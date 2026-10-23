# A vertical list that can be reordered by the user.
#
# Each row carries its own move buttons (up, down, to top, to bottom): real
# buttons, the accessible way to reorder.
#
# A button that cannot move the row (the first row's "up") stays in place as an
# inert, aria-disabled button, so focus has somewhere to stay after a move.
#
# Knows nothing of what the rows hold: the page gives the content, the address
# and the words.
class Core::UI::ReorderableListComponent < ApplicationComponent
  renders_many :rows, "Core::UI::ReorderableListComponent::Row"

  def initialize(label:, empty_text:)
    @label = label
    @empty_text = empty_text
  end

  def call
    return tag.p(@empty_text) if rows.empty?

    tag.div(data: {controller: "sortable", sortable_handle_value: "[data-sortable-handle]"}) do
      safe_join([tag.ol(safe_join(rows), "aria-label": @label, class: "space-y-2", data: {sortable_target: "list"}), drop_form])
    end
  end

  # What a drop sends: the sortable controller aims this form at the dropped
  # row's address and fills in the neighbor the row now follows (`after`) or, at
  # the top, precedes (`before`).
  def drop_form
    form_with(url: "#", method: :patch, hidden: true, data: {sortable_target: "form"}) do
      safe_join([hidden_field_tag(:after, nil, id: nil, data: {sortable_target: "after"}), hidden_field_tag(:before, nil, id: nil, data: {sortable_target: "before"})])
    end
  end

  # id: the element id.
  # item_id: what the server knows the row by (sent as the neighbor of a drop).
  # move_url: where a move is PATCHed (param `move`: up, down, top, bottom).
  # first/last: the row's place.
  # labels: {group:, up:, down:, top:, bottom:}, already written in the user's
  # language.
  # highlight: this row was just moved.
  class Row < ApplicationComponent
    MOVES = {up: :chevron_up, down: :chevron_down, top: :chevron_double_up, bottom: :chevron_double_down}.freeze
    # What each move cannot do from the first row and from the last.
    BLOCKED_AT_FIRST = %i[up top].freeze
    BLOCKED_AT_LAST = %i[down bottom].freeze
    HIGHLIGHT = {controller: "highlight", highlight_on_class: "bg-primary/20", highlight_off_class: "bg-base-100"}.freeze

    def initialize(id:, item_id:, move_url:, first:, last:, labels:, highlight: false)
      @id = id
      @item_id = item_id
      @move_url = move_url
      @first = first
      @last = last
      @labels = labels
      @highlight = highlight
    end

    def call
      data = {sortable_url: @move_url, sortable_item_id: @item_id}.merge(@highlight ? highlight_data : {})
      tag.li(id: @id, class: "flex flex-wrap items-start gap-2 rounded border border-base-300 bg-base-100 p-2", data:) do
        safe_join([handle, tag.div(content, class: "min-w-0 grow basis-40"), move_buttons])
      end
    end

    private

    # Only a pointer uses it: the buttons are the way for everyone else, so it
    # is hidden from assistive technology.
    def handle
      tag.span(render(Core::UI::IconComponent.new(name: :grip, class: "size-5", "stroke-width": "3")), "aria-hidden": "true", data: {sortable_handle: true},
        class: "flex size-6 shrink-0 cursor-grab touch-none items-center justify-center text-base-content/70")
    end

    # A new token each time the row is drawn, so a row that is still highlighted
    # from an earlier move starts over.
    def highlight_data = HIGHLIGHT.merge(highlight_token_value: SecureRandom.hex(4))

    def move_buttons
      tag.div(role: "group", "aria-label": @labels.fetch(:group), class: "shrink-0") do
        form_with(url: @move_url, method: :patch, class: "flex gap-1") do
          safe_join(MOVES.map { |move, icon| button(move, icon) })
        end
      end
    end

    def button(move, icon)
      label = @labels.fetch(move)
      options = {id: "#{@id}_#{move}", variant: :secondary, size: :xs, square: true, "aria-label": label, title: label, data: {move:}}
      options = blocked?(move) ? options.merge(type: :button, "aria-disabled": "true") : options.merge(type: :submit, name: "move", value: move)
      render(Core::UI::ButtonComponent.new(**options)) { render(Core::UI::IconComponent.new(name: icon, class: "size-4")) }
    end

    def blocked?(move) = (@first && BLOCKED_AT_FIRST.include?(move)) || (@last && BLOCKED_AT_LAST.include?(move))
  end
end
