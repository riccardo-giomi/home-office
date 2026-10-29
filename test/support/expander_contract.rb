# What every expansion adapter must do.
#
# The including test says which adapter it is by defining `expander`, an object
# answering `dates(rrule:, starts_on:, start_time:, time_zone:, between:)` with
# ascending local dates.
module ExpanderContract
  def self.included(base)
    base.class_eval do
      def dates(rrule, starts_on, between, start_time: "09:00", time_zone: "Europe/Rome")
        expander.dates(rrule:, starts_on: Date.parse(starts_on), start_time:, time_zone:, between: Date.parse(between.first)..Date.parse(between.last))
          .map(&:to_s)
      end

      it "repeats every N days" do
        _(dates("FREQ=DAILY;INTERVAL=3", "2026-10-01", %w[2026-10-01 2026-10-12])).must_equal %w[2026-10-01 2026-10-04 2026-10-07 2026-10-10]
      end

      it "repeats on the chosen weekdays" do
        _(dates("FREQ=WEEKLY;BYDAY=MO,WE", "2026-10-05", %w[2026-10-05 2026-10-18])).must_equal %w[2026-10-05 2026-10-07 2026-10-12 2026-10-14]
      end

      it "repeats every other week from the anchor week" do
        _(dates("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO", "2026-10-05", %w[2026-10-05 2026-11-02])).must_equal %w[2026-10-05 2026-10-19 2026-11-02]
      end

      it "skips the months that have no such day" do
        _(dates("FREQ=MONTHLY;BYMONTHDAY=31", "2026-01-31", %w[2026-01-01 2026-07-31])).must_equal %w[2026-01-31 2026-03-31 2026-05-31 2026-07-31]
      end

      it "finds the nth weekday of a month" do
        _(dates("FREQ=MONTHLY;BYDAY=2TU", "2026-01-13", %w[2026-01-01 2026-04-30])).must_equal %w[2026-01-13 2026-02-10 2026-03-10 2026-04-14]
      end

      it "finds the last weekday of a month" do
        _(dates("FREQ=MONTHLY;BYDAY=-1FR", "2026-01-30", %w[2026-01-01 2026-03-31])).must_equal %w[2026-01-30 2026-02-27 2026-03-27]
      end

      it "repeats yearly, a 29 February only in leap years" do
        _(dates("FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29", "2024-02-29", %w[2024-01-01 2033-01-01])).must_equal %w[2024-02-29 2028-02-29 2032-02-29]
      end

      it "stops after the until date, which is included" do
        _(dates("FREQ=DAILY;UNTIL=20261003", "2026-10-01", %w[2026-10-01 2026-10-10])).must_equal %w[2026-10-01 2026-10-02 2026-10-03]
      end

      it "stops after the count, also when the range starts later" do
        _(dates("FREQ=DAILY;COUNT=4", "2026-10-01", %w[2026-10-01 2026-10-31])).must_equal %w[2026-10-01 2026-10-02 2026-10-03 2026-10-04]
        _(dates("FREQ=DAILY;COUNT=4", "2026-10-01", %w[2026-10-03 2026-10-31])).must_equal %w[2026-10-03 2026-10-04]
      end

      it "includes both ends of the range" do
        _(dates("FREQ=DAILY", "2026-10-01", %w[2026-10-03 2026-10-04])).must_equal %w[2026-10-03 2026-10-04]
      end

      it "is empty before the anchor and for a range with no occurrence" do
        _(dates("FREQ=DAILY", "2026-10-10", %w[2026-10-01 2026-10-09])).must_equal []
        _(dates("FREQ=MONTHLY;BYMONTHDAY=31", "2026-01-31", %w[2026-04-01 2026-04-30])).must_equal []
      end

      it "gives dates for an all-day series" do
        _(dates("FREQ=WEEKLY;BYDAY=SU", "2026-10-04", %w[2026-10-04 2026-10-18], start_time: nil)).must_equal %w[2026-10-04 2026-10-11 2026-10-18]
      end

      it "keeps one date a week across the spring-forward and fall-back Sundays" do
        _(dates("FREQ=WEEKLY;BYDAY=SU", "2026-03-15", %w[2026-03-15 2026-04-05], start_time: "02:30")).must_equal %w[2026-03-15 2026-03-22 2026-03-29 2026-04-05]
        _(dates("FREQ=WEEKLY;BYDAY=SU", "2026-10-18", %w[2026-10-18 2026-11-08], start_time: "02:30")).must_equal %w[2026-10-18 2026-10-25 2026-11-01 2026-11-08]
      end

      it "starts at a wall-clock time that does not exist or happens twice, on the date it was given" do
        _(dates("FREQ=WEEKLY;BYDAY=SU", "2026-03-29", %w[2026-03-29 2026-04-12], start_time: "02:30")).must_equal %w[2026-03-29 2026-04-05 2026-04-12]
        _(dates("FREQ=WEEKLY;BYDAY=SU", "2026-10-25", %w[2026-10-25 2026-11-08], start_time: "02:30")).must_equal %w[2026-10-25 2026-11-01 2026-11-08]
      end

      it "reads an all-day series and a range in a zone whose day starts late on the day of the change" do
        _(dates("FREQ=DAILY", "2026-09-01", %w[2026-09-06 2026-09-07], start_time: nil, time_zone: "America/Santiago")).must_equal %w[2026-09-06 2026-09-07]
        _(dates("FREQ=DAILY", "2026-09-06", %w[2026-09-01 2026-09-07], start_time: "00:00", time_zone: "America/Santiago")).must_equal %w[2026-09-06 2026-09-07]
      end

      it "does not move a late evening to the next day in a zone far from UTC" do
        _(dates("FREQ=DAILY", "2026-10-01", %w[2026-10-01 2026-10-03], start_time: "23:30", time_zone: "America/Los_Angeles")).must_equal %w[2026-10-01 2026-10-02 2026-10-03]
      end
    end
  end
end
