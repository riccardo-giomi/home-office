# One entry of a list or a grid (an event, a task or a todo).
#
# Always the same shape, from top to bottom: a line with the done check and the
# statuses (only when there is a check or a status), the title as a link, and
# the time range.
#
# The "done" look is a struck-through title plus a hidden "Done", never color
# alone.
#
# The whole entry has a tooltip with the full title, the time range and the
# statuses, for a mouse user who has no room to see them.
#
# statuses: what is worth knowing at a glance, most important first. Each one is
# {icon:, label:} or {priority:, label:}, where priority is the level of the
# priority pill. A compact entry shows icons only; the others add the word when
# they are wide enough. A status can have a count:, a number that goes next to
# the icon when the word is not shown.
#
# commands: small buttons at the end of the same line, above the link that
# covers the entry. The page decides which entries get them.
#
# reveal: true when the address of the page asks for this entry (`at=<id>`).
# When the page opens, the entry scrolls to the center of the screen and its
# background is highlighted for two seconds.
class Core::UI::EntryComponent < ApplicationComponent
  renders_one :check
  renders_one :commands

  # The size of the icons and controls of the line at the top.
  STRIP_ICON = "size-6"

  # Controllers and classes added to an entry when `reveal` is true:
  #
  # `scroll-into-view` scrolls it to the center of the screen and `highlight`
  # swaps the background classes. The classes are written in full in this file
  # so that Tailwind includes them in the stylesheet.
  #
  # `highlight` comes last on purpose. It removes itself from the list when it
  # finishes, and Stimulus reconnects a controller whose position in the list
  # changes, which would scroll the page a second time.
  REVEAL = {
    controller: "scroll-into-view highlight",
    highlight_on_class: "bg-primary/20",
    highlight_off_class: "bg-base-100",
    scroll_into_view_block_value: "center"
  }.freeze

  def initialize(title:, href:, starts_at: nil, ends_at: nil, time_zone: nil, done: false, muted: false, compact: false, link_data: {}, statuses: [], show_time: true, reveal: false)
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
    @reveal = reveal
  end

  def call
    tag.div(class: "@container relative h-full min-w-0", title: tooltip, data: (REVEAL if @reveal)) do
      safe_join([lead, tag.div(title_link), time].compact)
    end
  end

  private

  # The check and the statuses are one line that never breaks, whatever the width:
  # what does not fit is clipped.
  def lead
    return unless check? || @statuses.any? || commands?

    tag.div(safe_join([check_above, status_strip, commands_end].compact), class: "flex flex-nowrap items-center gap-1 overflow-hidden")
  end

  # The done check stays above the link that covers the whole entry, so it can
  # still be ticked.
  def check_above = (tag.div(check, class: "relative z-10") if check?)

  # The commands stay above the link that covers the whole entry, so they can be
  # used, and go to the end of the line.
  def commands_end = (tag.div(commands, class: "relative z-10 ms-auto flex shrink-0 items-center gap-1") if commands?)

  def status_strip
    return if @statuses.empty?

    chips = @statuses.each_with_index.map { |status, index| status_chip(status, index) }
    tag.div(safe_join(chips), class: "flex shrink-0 flex-nowrap items-center gap-1 overflow-hidden")
  end

  # The entry is a container and decides by its own width what to show. Wide
  # enough, a chip has its words; narrower, only the icon; narrower still, only
  # the first chip, the most important.
  def status_chip(status, index)
    narrowest_hides = ("@max-[9rem]:hidden" if index.positive?)
    if status[:priority]
      pill = render(Core::UI::PriorityComponent.new(level: status[:priority], label: status[:label], compact: false))
      return tag.span(pill, class: narrowest_hides)
    end

    icon = render(Core::UI::IconComponent.new(name: status[:icon], class: "#{STRIP_ICON} shrink-0"))
    tag.span(safe_join([icon, *status_words(status)]), role: "img", "aria-label": status[:label], title: status[:label],
      class: ["inline-flex shrink-0 items-center gap-0.5 text-xs text-base-content/80", narrowest_hides])
  end

  # Next to the icon: the number, when there is one and the word is not shown,
  # and the word when there is room for it.
  def status_words(status)
    return [status[:count]].compact if @compact

    [(tag.span(status[:count], class: "@min-[14rem]:hidden") if status[:count]),
      tag.span(status[:label], class: "hidden @min-[14rem]:inline")].compact
  end

  def time
    return unless @show_time

    tag.span(time_range, class: ["block text-base-content/80", (@compact ? "text-xs" : "text-sm")])
  end

  def time_range
    return t("core.ui.entry.all_day") unless @starts_at

    safe_join([helpers.format_time(@starts_at, zone: @time_zone), "–", helpers.format_time(@ends_at, zone: @time_zone)])
  end

  # Lines: the full title, the time range, the statuses.
  def tooltip
    lines = [@title, (helpers.strip_tags(time_range) if @show_time), *@statuses.map { |status| status[:label] }]
    lines << t("core.ui.entry.done") if @done
    lines.compact.join("\n")
  end

  # The title is limited to two lines in a compact entry, with an ellipsis: the
  # card is clipped anyway, and the full title is in the tooltip.
  #
  # The link also covers the whole entry (the ::after), so the entry opens when
  # clicked anywhere, even where its title is clipped.
  def title_link
    text = @done ? safe_join([tag.s(@title), tag.span(" #{t("core.ui.entry.done")}", class: "sr-only")]) : @title
    text = tag.span(text, class: "line-clamp-2") if @compact
    link_to(text, @href, class: ["link inline-flex items-center min-h-6 wrap-anywhere after:absolute after:inset-0", ("opacity-70" if @done || @muted)], data: @link_data)
  end
end
