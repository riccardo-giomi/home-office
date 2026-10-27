# The calendar as plain reading: only the days that have something, one
# vertical list per day.
class Core::UI::AgendaListComponent < ApplicationComponent
  # days: [{date:, entries: [{title:, href:, starts_at:, ends_at:, time_zone:, done:, check:}]}]
  #
  # now: the current time in the viewer's zone; today's list then gets a
  # divider that a script moves along;
  #
  # scroll: whether the page scrolls by itself to today's list when it opens
  def initialize(days:, today:, empty_text:, now: nil, scroll: true)
    @days = days.select { |day| day[:entries].any? }
    @today = today
    @now = now
    @scroll = scroll
    @empty_text = empty_text
  end

  private

  # Where today's divider goes: before the first entry that has not started
  # yet, or after the last.
  def divider_before(day)
    return unless @now && day[:date] == @today

    minutes = @now.hour * 60 + @now.min
    day[:entries].index { |entry| entry[:from] && entry[:from] > minutes } || day[:entries].size
  end

  def render_divider
    tag.li("", "aria-hidden": "true", class: "relative my-1 border-t-2 border-primary before:absolute before:-top-[5px] before:-start-1 before:size-2 before:rounded-full before:bg-primary",
      data: {controller: "now-divider", now_divider_minutes_value: minutes_now, now_divider_rendered_at_value: rendered_at_ms})
  end

  def minutes_now = @now.hour * 60 + @now.min

  def rendered_at_ms = (@now.to_f * 1000).round

  def render_entry(attributes)
    render(Core::UI::EntryComponent.new(**attributes.except(:check, :from, :to, :commands))) do |entry|
      entry.with_check { attributes[:check] } if attributes[:check]
      entry.with_commands { attributes[:commands] } if attributes[:commands]
    end
  end
end
