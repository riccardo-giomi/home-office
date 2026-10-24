# Cards in a responsive grid: one column on a phone, more as the room grows. A
# list, so it is announced with its length; ready for as many cards as modules
# and dashboards will bring.
class Core::UI::CardGridComponent < ApplicationComponent
  renders_many :cards

  def initialize(label:)
    @label = label
  end

  def render? = cards.any?

  def call
    tag.ul(safe_join(cards.map { |card| tag.li(card) }), "aria-label": @label, class: "grid gap-4 sm:grid-cols-2 xl:grid-cols-3")
  end
end
