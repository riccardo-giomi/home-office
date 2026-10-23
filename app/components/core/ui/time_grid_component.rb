# One to seven days side by side on a 15-minute row grid, at every width (a
# phone shows one day; the calendar page decides).
#
# Overlaps are packed into columns by Core::ColumnPacking; each cluster of
# overlapping entries is its own subgrid.
#
# Placement is done with safelisted
# utility classes (see application.css), never an inline style.
class Core::UI::TimeGridComponent < ApplicationComponent
  SLOT_MINUTES = 15
  SLOTS = 24 * 60 / SLOT_MINUTES

  Slotted = Data.define(:attributes, :from, :to)
  Cluster = Data.define(:first_row, :rows, :columns, :placements)
  DayView = Data.define(:date, :column, :entries, :all_day, :result, :clusters, :now_minutes)

  # days: 1 to 7 of [{date:, entries: [{title:, href:, from:, to:, starts_at:, ends_at:, time_zone:, done:, check:}]}];
  # from/to are minutes from midnight in the entry's own zone, nil for an
  # all-day entry;
  #
  # now: the current time in the viewer's zone; today's column then gets a line
  # that a script moves along
  def initialize(days:, today:, agenda_href:, now: nil)
    @days = days
    @today = today
    @now = now
    @agenda_href = agenda_href
  end

  private

  def day_views
    @days.each_with_index.map do |day, index|
      timed = day[:entries].select { |entry| entry[:from] }.map { |entry| Slotted.new(entry, *snapped(entry[:from], entry[:to])) }
      result = Core::ColumnPacking.call(timed)
      DayView.new(date: day[:date], column: index + 2, entries: day[:entries], all_day: day[:entries].reject { |entry| entry[:from] },
        result:, clusters: clusters(result), now_minutes: (@now.hour * 60 + @now.min if @now && day[:date] == @today))
    end
  end

  # Entries are expanded vertically to fill whole slots of SLOT_MINUTES, so this
  # returns the interval as it is drawn, which is what the packing must work on.
  #
  # 09:00-10:10 covers five slots (09:00-09:15 to 10:00-10:15), so an entry
  # starting at 10:14 visually overlaps it and must share its cluster.
  def snapped(from, to) = [from / SLOT_MINUTES * SLOT_MINUTES, [(to + SLOT_MINUTES - 1) / SLOT_MINUTES * SLOT_MINUTES, SLOTS * SLOT_MINUTES].min]

  def clusters(result)
    result.placements.group_by(&:cluster).map do |_, placements|
      first = placements.map { |placement| slot_from(placement) }.min
      last = placements.map { |placement| slot_to(placement) }.max
      Cluster.new(first_row: first + 1, rows: [last - first, 1].max, columns: placements.first.columns, placements:)
    end
  end

  def slot_from(placement) = [placement.from / SLOT_MINUTES, SLOTS - 1].min

  def slot_to(placement) = [(placement.to + SLOT_MINUTES - 1) / SLOT_MINUTES, SLOTS].min

  def single_day? = @days.size == 1

  # Opens on the current time when today is shown, else on the morning (7:00):
  # midnight is rarely what is wanted.
  def scroll_mode = (@days.any? { |day| day[:date] == @today } && @now) ? "now" : "morning"

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
end
