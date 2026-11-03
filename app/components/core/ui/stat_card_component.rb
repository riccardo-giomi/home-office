# A card with a title and a list of labels and numbers (counts).
#
# A line is a count and a label. The title and each line are separate links;
# the card itself is not a link.
#
# Every line is drawn, including a count of 0, so that each count keeps its
# position.
#
# A title or line with a `narrow_href` is drawn as two anchors: one for screens
# narrower than 640 px and one for screens 640 px wide or wider. CSS hides one
# of them, and a hidden element is not in the accessibility tree, so a screen
# reader finds one link.
#
# lines: [{label:, count:, href:, narrow_href: nil}].
# total: text shown beside the title. It is not a link.
class Core::UI::StatCardComponent < ApplicationComponent
  CARD = "h-full rounded-box border border-base-300 bg-base-100 p-4"
  LINK = "underline underline-offset-2 hover:decoration-2 rounded-xs focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary wrap-anywhere"

  def initialize(title:, href:, lines:, narrow_href: nil, total: nil)
    @title = title
    @href = href
    @narrow_href = narrow_href
    @total = total
    @lines = lines
  end

  def call
    list = tag.ul(safe_join(@lines.map { |line| item(line) }), class: "mt-2 space-y-1")
    tag.article(safe_join([heading, list]), class: CARD, aria: {labelledby: heading_id})
  end

  private

  # Same value on every render. A refresh in place keeps the focus on the
  # heading only if the id does not change.
  def heading_id = @heading_id ||= "stat-card-#{"#{@title} #{@href}".parameterize}"

  def heading
    total = tag.span(@total, data: {part: "total"}, class: "ms-2 text-sm text-base-content/80") if @total
    tag.h2(id: heading_id, class: "wrap-anywhere") do
      safe_join([anchors(@title, @href, @narrow_href, "text-lg font-bold"), (" " if @total), total].compact)
    end
  end

  # Each link starts with the card title in visually hidden text, so that a
  # screen reader reading the link out of context ("Events: 7 This week")
  # announces what the count is about.
  def item(line)
    body = safe_join([
      tag.span("#{@title}: ", class: "sr-only"),
      tag.span(line[:count], data: {part: "count"}, class: "font-bold tabular-nums"),
      " ", line[:label]
    ])
    tag.li(anchors(body, line[:href], line[:narrow_href], "min-h-6 py-0.5", "hidden sm:block", "block sm:hidden", "block"))
  end

  # Returns one link, or two when `narrow_href` is given. Both have the same
  # text: one goes to `href` and shows from 640 px, the other goes to
  # `narrow_href` and shows below 640 px.
  def anchors(body, href, narrow_href, extra, wide_only = "hidden sm:inline", narrow_only = "sm:hidden", alone = nil)
    return link_to(body, href, class: [LINK, extra, alone]) unless narrow_href

    safe_join([
      link_to(body, href, class: [LINK, extra, wide_only]),
      link_to(body, narrow_href, class: [LINK, extra, narrow_only])
    ])
  end
end
