# A month in whole weeks.
#
# From the md breakpoint up a day lists its first entries; on a narrow screen
# it shows only the day number and how many entries it has, because titles do
# not fit seven columns at 320 px.
class Core::UI::MonthGridComponent < ApplicationComponent
  MAX_ENTRIES = 3

  # weeks: rows of seven dates;
  # entries_by_day: {Date => [{title:, href:, starts_at:, ends_at:, time_zone:, done:, check:}]};
  # day_href: ->(date) { path of the day view of that date }.
  def initialize(weeks:, month:, today:, caption:, day_href:, entries_by_day:)
    @weeks = weeks
    @month = month
    @today = today
    @caption = caption
    @day_href = day_href
    @entries_by_day = entries_by_day
  end

  private

  def weekday_headers = @weeks.first.map { |date| [I18n.t("date.day_names")[date.wday], I18n.t("date.abbr_day_names")[date.wday]] }

  def entries(date) = @entries_by_day.fetch(date, [])

  def outside_month?(date) = date.month != @month.month || date.year != @month.year

  def render_entry(attributes)
    render(Core::UI::EntryComponent.new(**attributes.except(:check, :from, :to))) do |entry|
      entry.with_check { attributes[:check] } if attributes[:check]
    end
  end
end
