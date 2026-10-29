# What a user says about how an event repeats.
#
# Daily, weekly on some weekdays, monthly on a day or on the nth weekday, yearly
# on a date, each with an interval and an end (never, on a date, after N
# times).
#
# It reads and writes the RRULE text the series stores, and only the
# rules it offers: anything else does not parse.
class Planner::Recurrence::Rule < Data.define(:frequency, :interval, :weekdays, :month_day, :nth_weekday, :month, :until_on, :count)
  FREQUENCIES = %w[daily weekly monthly yearly].freeze
  WEEKDAYS = %w[MO TU WE TH FR SA SU].freeze
  NTH_WEEKDAY = /\A(-1|[1-4])(#{WEEKDAYS.join("|")})\z/
  INTERVALS = 1..99
  COUNTS = 1..999

  def initialize(frequency:, interval: 1, weekdays: [], month_day: nil, nth_weekday: nil, month: nil, until_on: nil, count: nil) = super

  # A rule whose day-based parts follow the anchor date, unless the user chose
  # them.
  def self.for_anchor(anchor, frequency:, monthly: "day", **attributes)
    attributes = attributes.compact_blank
    case frequency.to_s
    when "weekly"
      attributes[:weekdays] = [WEEKDAYS.fetch(anchor.cwday - 1)] if attributes[:weekdays].blank?
    when "monthly"
      if monthly.to_s == "weekday"
        nth = ((anchor.day - 1) / 7) + 1
        attributes[:nth_weekday] ||= "#{(nth == 5) ? -1 : nth}#{WEEKDAYS.fetch(anchor.cwday - 1)}"
      else
        attributes[:month_day] ||= anchor.day
      end
    when "yearly"
      attributes[:month] ||= anchor.month
      attributes[:month_day] ||= anchor.day
    end
    new(frequency: frequency.to_s, **attributes)
  end

  # The rule a text says, or nil when the text is not one of the offered rules
  # (including one written in another order).
  def self.parse(text)
    parts = text.to_s.split(";").to_h { |part| part.split("=", 2) }
    byday = parts["BYDAY"].to_s
    frequency = parts["FREQ"].to_s.downcase
    rule = new(
      frequency:, interval: Integer(parts.fetch("INTERVAL", 1)),
      weekdays: (frequency == "weekly") ? byday.split(",") : [],
      nth_weekday: (byday.presence if frequency == "monthly"),
      month_day: (Integer(parts["BYMONTHDAY"]) if parts["BYMONTHDAY"]),
      month: (Integer(parts["BYMONTH"]) if parts["BYMONTH"]),
      until_on: (Date.strptime(parts["UNTIL"], "%Y%m%d") if parts["UNTIL"]),
      count: (Integer(parts["COUNT"]) if parts["COUNT"])
    )
    rule if rule.valid? && rule.to_rrule == text
  rescue ArgumentError, TypeError
    nil
  end

  def to_rrule
    parts = ["FREQ=#{frequency.upcase}"]
    parts << "INTERVAL=#{interval}" if interval != 1
    parts << "BYDAY=#{weekdays.join(",")}" if weekdays.any?
    parts << "BYDAY=#{nth_weekday}" if nth_weekday
    parts << "BYMONTH=#{month}" if month
    parts << "BYMONTHDAY=#{month_day}" if month_day
    parts << "UNTIL=#{until_on.strftime("%Y%m%d")}" if until_on
    parts << "COUNT=#{count}" if count
    parts.join(";")
  end

  # The attributes that are wrong, as symbols.
  def errors
    errors = []
    errors << :frequency unless FREQUENCIES.include?(frequency)
    errors << :interval unless INTERVALS.cover?(interval)
    errors << :count unless count.nil? || COUNTS.cover?(count)
    errors << :count if count && until_on
    errors.concat(day_errors)
  end

  def valid? = errors.empty?

  # The rule in words, like "Every 2 weeks on Mon, Wed, until 3 Dec 2026".
  def summary
    on = case frequency
    when "weekly" then words("on_weekdays", days: weekdays.map { |day| weekday_name(day) }.join(", "))
    when "monthly" then monthly_summary
    when "yearly" then words("on_date", day: month_day, month: I18n.t("date.abbr_month_names")[month])
    end
    ending = if until_on then words("until", date: I18n.l(until_on, format: "%-d %b %Y"))
    elsif count then words("times", count:)
    end
    [[words("every.#{frequency}", count: interval), on].compact.join(" "), ending].compact.join(", ")
  end

  private

  def monthly_summary
    return words("on_month_day", day: month_day) unless nth_weekday

    words("on_nth_weekday", nth: words("nth.#{nth_weekday[/\A-?\d/]}"), weekday: weekday_name(nth_weekday[-2, 2]))
  end

  # The short name of a weekday code ("MO"). The names start on Sunday.
  def weekday_name(code) = I18n.t("date.abbr_day_names")[(WEEKDAYS.index(code) + 1) % 7]

  def day_errors
    case frequency
    when "weekly"
      (weekdays.any? && weekdays.all? { |day| WEEKDAYS.include?(day) }) ? [] : [:weekdays]
    when "monthly"
      errors = []
      errors << :nth_weekday if nth_weekday && !NTH_WEEKDAY.match?(nth_weekday)
      errors << :month_day if month_day.nil? == nth_weekday.nil? || (month_day && !(1..31).cover?(month_day))
      errors
    when "yearly"
      errors = []
      errors << :month unless month.is_a?(Integer) && (1..12).cover?(month)
      errors << :month_day unless month_day.is_a?(Integer) && (1..31).cover?(month_day)
      errors
    else
      []
    end
  end

  def words(key, **options) = I18n.t("planner.recurrence.summary.#{key}", **options)
end
