# One dated entry (an event or a task): optional check, time range, title link.
# The "done" look is a struck-through title plus a hidden "Done", never color
# alone.
class Core::UI::CalendarEntryComponent < ApplicationComponent
  renders_one :check

  def initialize(title:, href:, starts_at: nil, ends_at: nil, time_zone: nil, done: false, compact: false, link_data: {})
    @title = title
    @href = href
    @starts_at = starts_at
    @ends_at = ends_at
    @time_zone = time_zone
    @done = done
    @compact = compact
    @link_data = link_data
  end

  def call
    # The text block wants at least 4rem (basis-16). When the card is too narrow
    # for the checkbox and 4rem of text side by side, the text moves to the line
    # below the checkbox instead of being squeezed.
    tag.div(class: "flex flex-wrap items-start gap-x-2 min-w-0") do
      safe_join([check, tag.div(time_and_title, class: "min-w-0 grow basis-16")].compact)
    end
  end

  private

  def time_and_title
    time = tag.span(time_text, class: ["block text-base-content/80", (@compact ? "text-xs" : "text-sm")])
    # Compact: inside a short card the title matters more than the time, so the
    # time is what gets clipped.
    safe_join(@compact ? [title_link, time] : [time, title_link])
  end

  def time_text
    return t("core.ui.calendar_entry.all_day") unless @starts_at

    safe_join([helpers.format_time(@starts_at, zone: @time_zone), "–", helpers.format_time(@ends_at, zone: @time_zone)])
  end

  def title_link
    label = @done ? safe_join([tag.s(@title), tag.span(" #{t("core.ui.calendar_entry.done")}", class: "sr-only")]) : @title
    link_to(label, @href, class: ["link inline-flex items-center min-h-6 wrap-anywhere", ("opacity-70" if @done)], data: @link_data)
  end
end
