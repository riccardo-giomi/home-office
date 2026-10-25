# One to seven days side by side on a 15-minute row grid, at every width (a
# phone shows one day; the calendar page decides).
#
# Overlaps are packed into columns by Core::ColumnPacking; each cluster of
# overlapping entries is its own subgrid.
#
# Placement is done with safelisted utility classes (see application.css),
# never an inline style.
#
# It draws only the stretches of the day it is given (segments, ranges of
# minutes). Two stretches are set apart by a break band one hour tall.
#
# Everything is placed in visible minutes, counted from the first visible row,
# the break included. An entry that crosses the edge of a stretch is clipped to
# it. One that is wholly outside is not drawn but counted, and the strip under
# the day's heading says so in words.
class Core::UI::TimeGridComponent < ApplicationComponent
  SLOT_MINUTES = 15
  DAY_MINUTES = Core::DaySlice::DAY_MINUTES
  BREAK_MINUTES = 60

  Slotted = Data.define(:attributes, :from, :to)
  Cluster = Data.define(:first_row, :rows, :columns, :placements)
  DayView = Data.define(:date, :column, :entries, :all_day, :result, :clusters, :today, :outside)
  Stretch = Data.define(:range, :offset)

  # days: 1 to 7 of [{date:, entries: [{title:, href:, from:, to:, starts_at:, ends_at:, time_zone:, done:, check:}]}];
  # from/to are minutes from midnight in the entry's own zone, nil for an
  # all-day entry;
  #
  # now: the current time in the viewer's zone; today's column then gets a line
  # that a script moves along;
  #
  # scroll: whether the grid scrolls by itself when the page opens. The caller
  # turns it off for a page asked for by date, so that moving between periods
  # leaves the page at the top, with the navigation;
  #
  # segments: the stretches of the day to draw, as ranges of minutes from
  # midnight (all of it by default);
  #
  # outside_href: ->(date) { href }, where the hours that are not drawn can be
  # seen, for the notice of hidden entries
  def initialize(days:, today:, agenda_href:, now: nil, scroll: true, segments: [0...DAY_MINUTES], outside_href: nil)
    @days = days
    @today = today
    @now = now
    @scroll = scroll
    @agenda_href = agenda_href
    @segments = segments.presence || [0...DAY_MINUTES]
    @outside_href = outside_href
  end

  private

  def day_views
    @days.each_with_index.map do |day, index|
      timed = day[:entries].select { |entry| entry[:from] }
      drawn, hidden = timed.partition { |entry| shown?(entry) }
      slotted = drawn.map { |entry| Slotted.new(entry, *snapped(visible_from(entry[:from]), visible_to(entry_end(entry)))) }
      result = Core::ColumnPacking.call(slotted)
      DayView.new(date: day[:date], column: index + 2, entries: day[:entries], all_day: day[:entries].reject { |entry| entry[:from] },
        result:, clusters: clusters(result), today: day[:date] == @today, outside: outside_notes(day[:date], hidden))
    end
  end

  # The stretches, each with where it starts among the visible minutes.
  # A break sits between two that do not touch.
  def stretches
    @stretches ||= begin
      offset = 0
      @segments.each_with_index.map do |range, index|
        offset += BREAK_MINUTES if index > 0 && range.begin > @segments[index - 1].end
        Stretch.new(range:, offset:).tap { offset += range.size }
      end
    end
  end

  def total_minutes = stretches.last.then { |stretch| stretch.offset + stretch.range.size }

  def total_rows = total_minutes / SLOT_MINUTES

  # An entry without an end, or ending when it starts, still takes a minute:
  # it must be seen.
  def entry_end(entry) = [entry[:to] || entry[:from], entry[:from] + 1].max

  def shown?(entry) = @segments.any? { |range| entry[:from] < range.end && entry_end(entry) > range.begin }

  # A minute in a hidden stretch moves to the edge of the next stretch that is
  # drawn (when it starts an entry) or of the last one (when it ends one).
  def visible_from(minute)
    stretch = stretches.find { |candidate| minute < candidate.range.end }
    stretch ? stretch.offset + [minute - stretch.range.begin, 0].max : total_minutes
  end

  def visible_to(minute)
    stretch = stretches.rfind { |candidate| minute > candidate.range.begin }
    stretch ? stretch.offset + [minute, stretch.range.end].min - stretch.range.begin : 0
  end

  # What sits in the gutter, top to bottom: an hour label, or the break.
  def gutter
    stretches.each_with_index.flat_map do |stretch, index|
      previous = stretches[index - 1] if index > 0
      lead = (previous && stretch.offset > previous.offset + previous.range.size) ? [:break] : []
      lead + (stretch.range.begin / 60...(stretch.range.end + 59) / 60).to_a
    end
  end

  # The first row (counting from 1, within the hours) of each break.
  def break_rows
    stretches.each_cons(2).filter_map do |before, after|
      (before.offset + before.range.size) / SLOT_MINUTES + 1 if after.offset > before.offset + before.range.size
    end
  end

  # [[:before, 2, href], ...]: the timed entries that are not drawn, grouped by
  # where they are.
  def outside_notes(date, hidden)
    hidden.group_by { |entry| outside_kind(entry) }.map do |kind, entries|
      [kind, entries.size, @outside_href&.call(date)]
    end.sort_by { |kind, _, _| %i[before between after].index(kind) }
  end

  def outside_kind(entry)
    if entry_end(entry) <= @segments.first.begin then :before
    elsif entry[:from] >= @segments.last.end then :after
    else :between
    end
  end

  def outside_note(kind, count, href)
    text = outside_text(kind, count)
    href ? link_to(text, href, class: "link inline-flex min-h-6 items-center") : text
  end

  # The sentence is translated whole, with the times in it.
  def outside_text(kind, count)
    first, last = @segments.first, @segments.last
    times = case kind
    when :before then {time: hour_text(first.begin / 60)}
    when :after then {time: hour_text(last.end / 60)}
    else {from: hour_text(first.end / 60), to: hour_text(@segments.second.begin / 60)}
    end
    t("core.ui.time_grid.outside.#{kind}", count:, **times)
  end

  # Entries are expanded vertically to fill whole slots of SLOT_MINUTES, so this
  # returns the interval as it is drawn, which is what the packing must work on.
  #
  # 09:00-10:10 covers five slots (09:00-09:15 to 10:00-10:15), so an entry
  # starting at 10:14 visually overlaps it and must share its cluster.
  def snapped(from, to) = [from / SLOT_MINUTES * SLOT_MINUTES, [(to + SLOT_MINUTES - 1) / SLOT_MINUTES * SLOT_MINUTES, total_minutes].min]

  def clusters(result)
    result.placements.group_by(&:cluster).map do |_, placements|
      first = placements.map { |placement| slot_from(placement) }.min
      last = placements.map { |placement| slot_to(placement) }.max
      Cluster.new(first_row: first + 1, rows: [last - first, 1].max, columns: placements.first.columns, placements:)
    end
  end

  def slot_from(placement) = [placement.from / SLOT_MINUTES, total_rows - 1].min

  def slot_to(placement) = [(placement.to + SLOT_MINUTES - 1) / SLOT_MINUTES, total_rows].min

  def single_day? = @days.size == 1

  # What the grid does by itself when the page opens: scroll so that the
  # current time is centered, if scrolling is allowed, today is shown and the
  # time is in one of the stretches. Otherwise nothing, and the page stays at
  # the top.
  #
  # The line hides itself while the clock is in a hidden stretch and shows when
  # it moves into one.
  def scroll_mode
    (@scroll && @now && @days.any? { |day| day[:date] == @today } && now_visible?) ? "now" : "none"
  end

  def now_visible? = @segments.any? { |range| range.cover?(now_minutes) }

  def now_minutes = @now.hour * 60 + @now.min

  # [[from, to, offset], ...]: for the script that places the line.
  def now_segments = stretches.map { |stretch| [stretch.range.begin, stretch.range.end, stretch.offset] }

  def rendered_at_ms = (@now.to_f * 1000).round

  # Seven narrow columns need small text and little padding for a word to fit;
  # one wide column does not.
  def entry_classes(cluster, placement)
    rows = [slot_to(placement) - slot_from(placement), 1].max
    ["rounded border border-base-300 bg-base-100 overflow-hidden", (single_day? ? "p-1 text-sm" : "p-0.5 text-xs"),
      "row-start-#{slot_from(placement) - cluster.first_row + 2} row-span-#{rows} col-start-#{placement.column + 1}"].join(" ")
  end

  # Under 45 minutes (fewer than three rows) a card has no room for the time
  # above the title: the title comes first and the time is what gets clipped.
  #
  # A seven-day grid is always compact.
  def compact?(placement) = !single_day? || slot_to(placement) - slot_from(placement) < 3

  def render_entry(attributes, compact: !single_day?)
    render(Core::UI::EntryComponent.new(**attributes.except(:check, :from, :to), compact:)) do |entry|
      entry.with_check { attributes[:check] } if attributes[:check]
    end
  end

  def hour_label(hour) = helpers.format_time(Time.utc(2000, 1, 1, hour), zone: "UTC")

  def hour_text(hour) = helpers.format_time_text(Time.utc(2000, 1, 1, hour), zone: "UTC")
end
