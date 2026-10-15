# A choice between views of the same thing, as links: every tab has an address of its own, so it can be
# bookmarked, shared and reached with the back button (the state lives in the URL, not in the page).
# Put it inside a labeled navigation, or give it a label of its own.
class Core::UI::TabsComponent < ApplicationComponent
  # The same quiet gray as a secondary button; the current tab is the one solid button
  BUTTON = "btn btn-sm #{Core::UI::ButtonComponent::VARIANTS.fetch(:secondary)}".freeze
  CURRENT = "btn btn-sm btn-neutral".freeze

  # items: [[label, href, current?], ...]
  def initialize(items:, label: nil)
    @items = items
    @label = label
  end

  def call
    tag.ul(class: "flex flex-wrap gap-2", "aria-label": @label) do
      safe_join(@items.map { |text, href, current| tag.li(link(text, href, current)) })
    end
  end

  private

  def link(text, href, current)
    link_to(href, class: (current ? CURRENT : BUTTON), "aria-current": ("true" if current)) do
      safe_join([(render(Core::UI::IconComponent.new(name: :check)) if current), text].compact)
    end
  end
end
