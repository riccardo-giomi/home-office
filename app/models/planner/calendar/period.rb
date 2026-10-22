# What the calendar page shows: a view (as in month, day or week) and a date,
# turned into the dates it covers.
# Anything unreadable falls back to today and the month, so a hand-edited URL
# never errors.
class Planner::Calendar::Period
  VIEWS = %i[month week day].freeze
  WEEKDAYS = %i[sunday monday tuesday wednesday thursday friday saturday].freeze
  BOUNDS = Date.new(1900, 1, 1)..Date.new(2200, 12, 31)

  attr_reader :view, :views, :date, :first_weekday

  # views: the views this page offers (the schedule has two); default: the one
  # used for anything else.
  def initialize(view:, date:, first_weekday:, today:, views: VIEWS, default: :month)
    @views = views
    @default = default
    @view = views.find { |candidate| candidate.to_s == view.to_s } || default
    @date = parse(date) || today
    @first_weekday = first_weekday
    freeze
  end

  def range
    case view
    when :week then week_range
    when :day then date..date
    else date.beginning_of_month..date.end_of_month
    end
  end

  # The month grid is drawn in whole weeks; the other views cover exactly their
  # range
  def grid_range
    return range unless view == :month

    range.first.beginning_of_week(weekday)..range.last.end_of_week(weekday)
  end

  def days_of_week = week_range.to_a

  def previous = shifted(-1)

  def next = shifted(1)

  def with_view(new_view) = self.class.new(view: new_view, date:, first_weekday:, today: date, views:, default: @default)

  def to_params = {view: view.to_s, date: date.iso8601}

  private

  def weekday = WEEKDAYS.fetch(first_weekday)

  def week_range = date.beginning_of_week(weekday)..date.end_of_week(weekday)

  def shifted(step)
    moved = case view
    when :week then date + (7 * step)
    when :day then date + step
    else date.advance(months: step)
    end
    self.class.new(view:, date: moved, first_weekday:, today: date, views:, default: @default)
  end

  def parse(value)
    parsed = Date.iso8601(value.to_s)
    parsed if BOUNDS.cover?(parsed)
  rescue Date::Error
    nil
  end
end
