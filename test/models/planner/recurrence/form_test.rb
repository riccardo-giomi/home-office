require "test_helper"

describe Planner::Recurrence::Form do
  def form(**attributes) = Planner::Recurrence::Form.new(**attributes)

  let(:anchor) { Date.new(2026, 10, 5) } # a Monday

  it "does not repeat by default" do
    _(form).wont_be :repeating?
    _(form(frequency: "never")).wont_be :repeating?
    _(form(frequency: "weekly")).must_be :repeating?
  end

  it "reads what the request typed, as strings" do
    built = form(frequency: "weekly", interval: "2", weekdays: ["", "MO", "WE"], ends: "until", until_on: "2026-12-03")
    rule = built.rule_for(anchor)
    _(rule).must_equal Planner::Recurrence::Rule.new(frequency: "weekly", interval: 2, weekdays: %w[MO WE], until_on: Date.new(2026, 12, 3))
    _(built.errors).must_be :empty?
  end

  it "takes the day-based parts from the anchor" do
    _(form(frequency: "weekly").rule_for(anchor).weekdays).must_equal %w[MO]
    _(form(frequency: "monthly").rule_for(anchor).month_day).must_equal 5
    _(form(frequency: "monthly", monthly: "weekday").rule_for(anchor).nth_weekday).must_equal "1MO"
    _(form(frequency: "yearly").rule_for(anchor).to_rrule).must_equal "FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=5"
  end

  it "ignores the fields of another frequency, which a hidden field still sends" do
    _(form(frequency: "monthly", weekdays: %w[MO WE]).rule_for(anchor).to_rrule).must_equal "FREQ=MONTHLY;BYMONTHDAY=5"
    _(form(frequency: "daily", weekdays: %w[MO], monthly: "weekday").rule_for(anchor).to_rrule).must_equal "FREQ=DAILY"
    _(form(frequency: "weekly", monthly: "weekday").rule_for(anchor).to_rrule).must_equal "FREQ=WEEKLY;BYDAY=MO"
    _(form(frequency: "yearly", weekdays: %w[MO]).rule_for(anchor).to_rrule).must_equal "FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=5"
  end

  it "ignores the end it was not asked for" do
    _(form(frequency: "daily", ends: "never", until_on: "2026-12-03", count: "4").rule_for(anchor).to_rrule).must_equal "FREQ=DAILY"
    _(form(frequency: "daily", ends: "count", until_on: "2026-12-03", count: "4").rule_for(anchor).to_rrule).must_equal "FREQ=DAILY;COUNT=4"
  end

  it "says what is wrong, on the attribute that is wrong" do
    {
      {frequency: "daily", interval: "0"} => :interval,
      {frequency: "daily", interval: "100"} => :interval,
      {frequency: "daily", interval: "abc"} => :interval,
      {frequency: "daily", ends: "count", count: ""} => :count,
      {frequency: "daily", ends: "count", count: "1000"} => :count,
      {frequency: "daily", ends: "until", until_on: ""} => :until_on,
      {frequency: "daily", ends: "until", until_on: "2026-10-04"} => :until_on,
      {frequency: "daily", ends: "until", until_on: "not a date"} => :until_on,
      {frequency: "weekly", weekdays: ["", "XX"]} => :weekdays,
      {frequency: "hourly"} => :frequency
    }.each do |attributes, attribute|
      built = form(**attributes)
      _(built.rule_for(anchor)).must_be_nil
      _(built.errors).must_include attribute
      _(built.errors.full_messages.first).wont_include "translation missing"
    end
  end

  it "has no rule when it does not repeat" do
    built = form
    _(built.rule_for(anchor)).must_be_nil
    _(built.errors).must_be :empty?
  end

  it "names its fields repeat[...] and its errors in words" do
    _(Planner::Recurrence::Form.model_name.param_key).must_equal "repeat"
    built = form(frequency: "daily", interval: "0")
    built.rule_for(anchor)
    _(built.errors.full_messages).must_equal ["Interval must be a number from 1 to 99"]
  end
end
