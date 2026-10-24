# A plain vertical list of rows: the main text, an optional detail line under
# it, and optional actions beside it (they wrap below on a narrow screen).
# It knows nothing of what the rows hold.
class Core::UI::RowListComponent < ApplicationComponent
  renders_many :rows, "Core::UI::RowListComponent::Row"

  def initialize(label:, empty_text:)
    @label = label
    @empty_text = empty_text
  end

  def call
    return tag.p(@empty_text) if rows.empty?

    tag.ol(safe_join(rows), "aria-label": @label, class: "space-y-2")
  end

  class Row < ApplicationComponent
    def initialize(id: nil, detail: nil, actions: nil)
      @id = id
      @detail = detail
      @actions = actions
    end

    def call
      tag.li(id: @id, class: "flex flex-wrap items-center gap-2 rounded border border-base-300 bg-base-100 p-2") do
        text = tag.div(content, class: "font-medium wrap-anywhere")
        detail = (tag.div(@detail, class: "text-sm text-base-content/80") if @detail)
        body = tag.div(safe_join([text, detail].compact), class: "min-w-0 grow basis-48")
        safe_join([body, @actions].compact)
      end
    end
  end
end
