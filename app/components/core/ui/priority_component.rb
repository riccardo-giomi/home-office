# How much an item matters to the person who made it: a small pill with four
# bars, one more filled at each level.
#
# The number of filled bars is the shape cue and the color is a second one. The
# words are for readers: the full name is the accessible name and the tooltip,
# so no translation has to fit inside the pill.
#
# Normal is the baseline, so it is silent unless asked for (`always:`).
class Core::UI::PriorityComponent < ApplicationComponent
  # Low is green, high is amber, urgent is red; normal is neutral. Solid pills
  # carry their own content color.
  LEVELS = {
    low: {bars: 1, css: "badge-success"},
    normal: {bars: 2, css: "border-base-300 bg-base-100 text-base-content"},
    high: {bars: 3, css: "badge-warning"},
    urgent: {bars: 4, css: "badge-error"}
  }.freeze
  BAR_HEIGHTS = [4, 7, 10, 13].freeze

  # label: the full name ("High priority"), already in the user's language.
  def initialize(level:, label:, compact: false, always: false)
    @level = level.to_sym
    @config = LEVELS.fetch(@level)
    @label = label
    @compact = compact
    @always = always
  end

  def render? = @always || @level != :normal

  def call
    tag.span(bars, role: "img", "aria-label": @label, title: @label,
      class: ["badge", (@compact ? "badge-sm px-1.5" : "badge-md px-2"), @config[:css]])
  end

  private

  # Four bars growing to the right; the ones above the actual priority level
  # are faint (30% opacity).
  def bars
    tag.svg(safe_join(BAR_HEIGHTS.each_with_index.map { |height, index| bar(height, index) }),
      xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 16 16", fill: "currentColor", "aria-hidden": "true", class: [(@compact ? "size-3.5" : "size-4"), "shrink-0"])
  end

  def bar(height, index)
    tag.rect(x: (index * 4) + 0.5, y: 15 - height, width: 3, height:, rx: 0.5, opacity: (0.3 if index >= @config[:bars]))
  end
end
