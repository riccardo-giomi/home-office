# One entry of a list or a grid (an event, a task or a todo).
#
# From top to bottom: a strip of statuses (only when there are any), the title
# as a link, and the time range. The optional done check is on the left.
#
# The "done" look is a struck-through title plus a hidden "Done", never color
# alone.
#
# The whole entry has a tooltip with the full title, the time range and the
# statuses, for a mouse user who has no room to see them.
#
# statuses: what is worth knowing at a glance, most important first. Each one is
# {icon:, label:} or {priority:, label:}, where priority is the level of the
# priority pill. A compact entry shows icons only; the others add the word.
class Core::UI::CalendarEntryComponent < ApplicationComponent
  renders_one :check

  def initialize(title:, href:, starts_at: nil, ends_at: nil, time_zone: nil, done: false, muted: false, compact: false, link_data: {}, statuses: [], show_time: true)
    @title = title
    @href = href
    @starts_at = starts_at
    @ends_at = ends_at
    @time_zone = time_zone
    @done = done
    @muted = muted
    @compact = compact
    @link_data = link_data
    @statuses = statuses
    @show_time = show_time
  end

  def call
    tag.div(class: "relative flex h-full min-w-0 flex-wrap content-start items-start gap-x-2", title: tooltip) do
      safe_join(@compact ? compact_parts : full_parts)
    end
  end

  private

  # A compact entry (a card in a grid) has three parts: the done check and the
  # statuses on one line that never breaks, the title, and the time range. The
  # title shares the first line when there is room for it, else it goes below.
  def compact_parts
    [lead, tag.div(title_link, class: "min-w-0 grow basis-16"), time].compact
  end

  # The check on the left, and the text block beside it. The text block wants at
  # least 4rem (basis-16): when the entry is too narrow for the check and 4rem of
  # text side by side, the text goes to the line below the check instead of
  # being squeezed. The statuses have their own line in the text block.
  def full_parts
    strip = status_strip
    [check_above, tag.div(safe_join([strip, title_link, time].compact), class: "min-w-0 grow basis-16")].compact
  end

  # The check and the statuses are never split on two lines, whatever the width:
  # what does not fit is clipped.
  def lead
    return unless check? || @statuses.any?

    tag.div(safe_join([check_above, status_strip].compact), class: "flex max-w-full shrink-0 flex-nowrap items-center gap-1 overflow-hidden")
  end

  # The done check stays above the link that covers the whole entry, so it can
  # still be ticked.
  def check_above = (tag.div(check, class: "relative z-10") if check?)

  def status_strip
    return if @statuses.empty?

    tag.div(safe_join(@statuses.map { |status| status_chip(status) }), class: "flex shrink-0 flex-nowrap items-center gap-1 overflow-hidden")
  end

  def status_chip(status)
    # The small pill, in any entry: it must match the 16 px icons of the other
    # chips.
    return render(Core::UI::PriorityComponent.new(level: status[:priority], label: status[:label], compact: true)) if status[:priority]

    icon = render(Core::UI::IconComponent.new(name: status[:icon], class: "size-4 shrink-0"))
    if @compact
      tag.span(icon, role: "img", "aria-label": status[:label], title: status[:label], class: "shrink-0")
    else
      tag.span(safe_join([icon, status[:label]], " "), class: "inline-flex shrink-0 items-center gap-1 text-xs text-base-content/80")
    end
  end

  def time
    return unless @show_time

    tag.span(time_range, class: ["block basis-full text-base-content/80", (@compact ? "text-xs" : "text-sm")])
  end

  def time_range
    return t("core.ui.calendar_entry.all_day") unless @starts_at

    safe_join([helpers.format_time(@starts_at, zone: @time_zone), "–", helpers.format_time(@ends_at, zone: @time_zone)])
  end

  # Lines: the full title, the time range, the statuses.
  def tooltip
    lines = [@title, (helpers.strip_tags(time_range) if @show_time), *@statuses.map { |status| status[:label] }]
    lines << t("core.ui.calendar_entry.done") if @done
    lines.compact.join("\n")
  end

  # The title is limited to two lines in a compact entry, with an ellipsis: the
  # card is clipped anyway, and the full title is in the tooltip.
  #
  # The link also covers the whole entry (the ::after), so the entry opens when
  # clicked anywhere, even where its title is clipped.
  def title_link
    text = @done ? safe_join([tag.s(@title), tag.span(" #{t("core.ui.calendar_entry.done")}", class: "sr-only")]) : @title
    text = tag.span(text, class: "line-clamp-2") if @compact
    link_to(text, @href, class: ["link inline-flex items-center min-h-6 wrap-anywhere after:absolute after:inset-0", ("opacity-70" if @done || @muted)], data: @link_data)
  end
end
