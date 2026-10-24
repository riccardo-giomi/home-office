# A whole card that is one link: a title, an optional caption and short lines
# (counts, as text).
#
# The card contains no other control element, so it stays a one-tab step with a
# name that is its visible text.
class Core::UI::CardLinkComponent < ApplicationComponent
  CLASSES = "block h-full rounded-box border border-base-300 bg-base-100 p-4 hover:bg-base-300 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"

  def initialize(href:, title:, lines:, caption: nil)
    @href = href
    @title = title
    @caption = caption
    @lines = lines
  end

  def call
    link_to(@href, class: CLASSES) do
      title = tag.span(@title, class: "block text-lg font-bold wrap-anywhere")
      caption = (tag.span(@caption, class: "block text-sm text-base-content/80 wrap-anywhere") if @caption)
      lines = @lines.map { |line| tag.span(line, class: "block wrap-anywhere") }
      safe_join([title, caption, *lines].compact)
    end
  end
end
