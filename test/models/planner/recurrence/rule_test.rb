require "test_helper"

Rule = Planner::Recurrence::Rule

describe Rule do
  let(:anchor) { Date.new(2026, 10, 5) } # a Monday

  def rule(**attributes) = Rule.new(frequency: "daily", **attributes)

  describe "the RRULE string" do
    it "round-trips every offered rule" do
      {
        rule(frequency: "daily") => "FREQ=DAILY",
        rule(frequency: "daily", interval: 3) => "FREQ=DAILY;INTERVAL=3",
        rule(frequency: "weekly", interval: 2, weekdays: %w[MO WE]) => "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE",
        rule(frequency: "monthly", month_day: 31) => "FREQ=MONTHLY;BYMONTHDAY=31",
        rule(frequency: "monthly", nth_weekday: "2TU") => "FREQ=MONTHLY;BYDAY=2TU",
        rule(frequency: "monthly", nth_weekday: "-1FR") => "FREQ=MONTHLY;BYDAY=-1FR",
        rule(frequency: "yearly", month: 2, month_day: 29) => "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29",
        rule(frequency: "daily", until_on: Date.new(2026, 12, 3)) => "FREQ=DAILY;UNTIL=20261203",
        rule(frequency: "weekly", weekdays: %w[SU], count: 10) => "FREQ=WEEKLY;BYDAY=SU;COUNT=10"
      }.each do |built, text|
        _(built.to_rrule).must_equal text
        _(Rule.parse(text).to_rrule).must_equal text
        _(Rule.parse(text)).must_equal built
      end
    end

    it "does not parse what it does not offer" do
      ["FREQ=SECONDLY", "FREQ=DAILY;BYHOUR=3", "FREQ=WEEKLY;BYDAY=2MO", "", "nonsense", "FREQ=DAILY;COUNT=3;UNTIL=20261203"].each do |text|
        _(Rule.parse(text)).must_be_nil
      end
    end
  end

  describe "taking the day-based parts from the anchor" do
    it "fills the weekday, the day of the month, the month" do
      _(Rule.for_anchor(anchor, frequency: "weekly").weekdays).must_equal %w[MO]
      _(Rule.for_anchor(anchor, frequency: "monthly").month_day).must_equal 5
      _(Rule.for_anchor(anchor, frequency: "monthly", monthly: "weekday").nth_weekday).must_equal "1MO"
      _(Rule.for_anchor(Date.new(2026, 10, 29), frequency: "monthly", monthly: "weekday").nth_weekday).must_equal "-1TH"
      yearly = Rule.for_anchor(Date.new(2026, 2, 28), frequency: "yearly")
      _(yearly.to_rrule).must_equal "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=28"
    end

    it "keeps what the user chose" do
      _(Rule.for_anchor(anchor, frequency: "weekly", weekdays: %w[TU FR]).weekdays).must_equal %w[TU FR]
    end
  end

  describe "validity" do
    it "accepts the offered rules" do
      _(rule).must_be :valid?
      _(rule(frequency: "weekly", weekdays: %w[MO])).must_be :valid?
      _(rule(frequency: "daily", count: 999)).must_be :valid?
    end

    it "refuses what is out of range or incomplete" do
      {
        rule(frequency: "secondly") => :frequency,
        rule(interval: 0) => :interval,
        rule(interval: 100) => :interval,
        rule(count: 0) => :count,
        rule(count: 1000) => :count,
        rule(frequency: "weekly", weekdays: []) => :weekdays,
        rule(frequency: "weekly", weekdays: %w[XX]) => :weekdays,
        rule(frequency: "monthly") => :month_day,
        rule(frequency: "monthly", month_day: 32) => :month_day,
        rule(frequency: "monthly", month_day: 5, nth_weekday: "2TU") => :month_day,
        rule(frequency: "monthly", nth_weekday: "6TU") => :nth_weekday,
        rule(frequency: "yearly", month: 13, month_day: 1) => :month,
        rule(until_on: Date.new(2026, 12, 3), count: 3) => :count
      }.each do |built, attribute|
        _(built).wont_be :valid?
        _(built.errors).must_include attribute
      end
    end
  end

  describe "the summary in words" do
    it "describes the rule in English" do
      I18n.with_locale(:en) do
        _(rule(frequency: "weekly", interval: 2, weekdays: %w[MO WE], until_on: Date.new(2026, 12, 3)).summary).must_equal "Every 2 weeks on Mon, Wed, until 3 Dec 2026"
        _(rule(frequency: "daily").summary).must_equal "Every day"
        _(rule(frequency: "monthly", month_day: 10).summary).must_equal "Every month on day 10"
        _(rule(frequency: "monthly", nth_weekday: "2TU", count: 6).summary).must_equal "Every month on the 2nd Tue, 6 times"
        _(rule(frequency: "monthly", nth_weekday: "-1FR").summary).must_equal "Every month on the last Fri"
        _(rule(frequency: "yearly", month: 2, month_day: 29).summary).must_equal "Every year on 29 Feb"
      end
    end

    it "describes the rule in Italian" do
      I18n.with_locale(:it) do
        _(rule(frequency: "weekly", interval: 2, weekdays: %w[MO WE]).summary).must_equal "Ogni 2 settimane il lun, mer"
        _(rule(frequency: "daily").summary).must_equal "Ogni giorno"
      end
    end
  end
end
