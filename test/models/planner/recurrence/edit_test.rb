require "test_helper"

describe Planner::Recurrence::Edit do
  let(:user) { users(:member) }
  let(:rent) do
    Planner::Series.create!(user:, title: "Rent", notes: "Bank transfer", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome",
      rrule: "FREQ=MONTHLY;BYMONTHDAY=5", start_time: "09:00", duration_minutes: 60, tracks_done: 1)
  end

  def date(text) = Date.parse(text)

  # What the edit form posts for an occurrence, with the changes the user made
  def posted(item, **changes)
    {title: item.title, notes: item.notes.to_s, priority: item.priority, tracks_done: item.tracks_done.to_s, day: item.day.iso8601,
     start_time: item.start_time.to_s, end_time: item.end_time.to_s}.merge(changes)
  end

  # The repeat fields of a series, with changes
  def repeat(series, **changes) = Planner::Recurrence::Form.from_rule(series.rule).tap { |form| changes.each { |name, value| form.public_send(:"#{name}=", value) } }

  def edit(series, on, scope, form: nil, **changes)
    item = series.occurrence(date(on))
    result = Planner::Recurrence::Edit.new(series:, item:, scope:, attributes: posted(item, **changes), form: form || repeat(series)).call
    [result, item]
  end

  def shown(series_list, range = date("2026-10-01")..date("2027-03-31"))
    Planner::Occurrences.for(user, range).map { |event| [event.day.to_s, event.title] }
  end

  describe "this and following" do
    it "splits the series at the occurrence: the old part ends the day before, a new part of the same chain takes over" do
      ok, = edit(rent, "2026-11-05", "following", title: "Rent and bills")
      _(ok).must_equal true
      rent.reload
      _(rent.ends_on).must_equal date("2026-11-04")
      newer = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      _([newer.title, newer.starts_on, newer.ends_on, newer.rrule, newer.chain_key, newer.start_time, newer.duration_minutes]).must_equal ["Rent and bills", date("2026-11-05"), nil, "FREQ=MONTHLY;BYMONTHDAY=5", rent.id, "09:00", 60]
      _(rent.chain.map(&:id)).must_equal [rent.id, newer.id]
      _(shown([rent]).first(4)).must_equal [["2026-10-05", "Rent"], ["2026-11-05", "Rent and bills"], ["2026-12-05", "Rent and bills"], ["2027-01-05", "Rent and bills"]]
    end

    it "changes the series itself when the occurrence is the first one" do
      rent
      assert_no_difference "Planner::Series.count" do
        ok, = edit(rent, "2026-10-05", "following", title: "Flat rent")
        _(ok).must_equal true
      end
      _(rent.reload.title).must_equal "Flat rent"
      _([rent.starts_on, rent.ends_on, rent.chain_id]).must_equal [date("2026-10-05"), nil, nil]
    end

    it "moves the day for good: the rule follows the new day and the old day is gone from then on" do
      ok, = edit(rent, "2026-11-05", "following", day: "2026-11-10")
      _(ok).must_equal true
      _(rent.reload.ends_on).must_equal date("2026-11-04")
      newer = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      _([newer.starts_on, newer.rrule]).must_equal [date("2026-11-10"), "FREQ=MONTHLY;BYMONTHDAY=10"]
      _(shown([rent]).first(4).map(&:first)).must_equal %w[2026-10-05 2026-11-10 2026-12-10 2027-01-10]
    end

    it "refuses a last day before the occurrence, and says to choose all events" do
      form = repeat(rent, ends: "until", until_on: date("2026-10-20"))
      ok, = edit(rent, "2026-11-05", "following", form:)
      _(ok).must_equal false
      _(form.errors.of_kind?(:until_on, :before_occurrence)).must_equal true
      _(rent.reload.ends_on).must_be_nil
    end

    it "forgets what was done in the events it reaches when they stop tracking it, and only in them" do
      rows = %w[2026-10-05 2026-11-05 2026-12-05].map { |day| rent.materialize(date(day)).tap { |row| row.mark_done(true) && row.save! } }
      ok, = edit(rent, "2026-11-05", "following", tracks_done: "0")
      _(ok).must_equal true
      _(rows.map { |row| Planner::Event.find(row.id).done? }).must_equal [true, false, false]
    end

    it "moves the day of the first occurrence in the series itself" do
      ok, = edit(rent, "2026-10-05", "following", day: "2026-10-12")
      _(ok).must_equal true
      _([rent.reload.starts_on, rent.rrule]).must_equal [date("2026-10-12"), "FREQ=MONTHLY;BYMONTHDAY=12"]
      _(Planner::Series.count).must_equal 1
    end

    it "refuses a new day on or before the occurrence before it, and changes nothing" do
      ["2026-10-05", "2026-10-03"].each do |day|
        ok, item = edit(rent, "2026-11-05", "following", day:, title: "Nope")
        _(ok).must_equal false
        _(item.errors).must_include :day
      end
      _(Planner::Series.count).must_equal 1
      _([rent.reload.ends_on, rent.title]).must_equal [nil, "Rent"]
    end

    it "refuses an invalid occurrence, and changes nothing" do
      ok, item = edit(rent, "2026-11-05", "following", title: " ")
      _(ok).must_equal false
      _(item.errors).must_include :title
      _(Planner::Series.count).must_equal 1
    end

    it "moves the touched rows from the occurrence on to the new part, leaving the earlier ones" do
      october = rent.materialize(date("2026-10-05")).tap { |row| row.update!(done_at: Time.current) }
      december = rent.materialize(date("2026-12-05")).tap { |row| row.update!(done_at: Time.current) }
      edit(rent, "2026-11-05", "following", notes: "Pay by the 5th")
      newer = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      _(october.reload.series_id).must_equal rent.id
      _(december.reload.series_id).must_equal newer.id
      _(december).must_be :done?
    end

    it "changes only what was changed in the rows it reaches, and the edited row entirely" do
      december = rent.materialize(date("2026-12-05")).tap { |row| row.update!(title: "Rent (late)") }
      november = rent.materialize(date("2026-11-05"))
      edit(rent, "2026-11-05", "following", notes: "Pay by the 5th", title: "Rent")
      _(december.reload.attributes.values_at("title", "notes")).must_equal ["Rent (late)", "Pay by the 5th"]
      _(november.reload.notes).must_equal "Pay by the 5th"
    end

    it "keeps a row that the new rule no longer gives as an event of its own, with its state" do
      december = rent.materialize(date("2026-12-05")).tap { |row| row.update!(done_at: Time.current) }
      edit(rent, "2026-11-05", "following", day: "2026-11-10")
      december.reload
      _([december.series_id, december.occurrence_on, december.day, december.done?]).must_equal [nil, nil, date("2026-12-05"), true]
      _(Planner::Event.where(id: december.id)).must_be :exists?
    end

    it "takes the edited row to the new day with it, as the first of the new part" do
      november = rent.materialize(date("2026-11-05")).tap { |row| row.update!(done_at: Time.current) }
      edit(rent, "2026-11-05", "following", day: "2026-11-10")
      newer = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      november.reload
      _([november.series_id, november.occurrence_on, november.day, november.starts_at.in_time_zone("Europe/Rome").hour, november.done?]).must_equal [newer.id, date("2026-11-10"), date("2026-11-10"), 9, true]
    end

    it "carries the deleted dates the new rule still gives" do
      rent.exclusions.create!(user_id: user.id, excluded_on: date("2026-12-05"))
      rent.exclusions.create!(user_id: user.id, excluded_on: date("2026-10-05"))
      edit(rent, "2026-11-05", "following", title: "Rent and bills")
      newer = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      _(Planner::SeriesExclusion.where(series_id: newer.id).pluck(:excluded_on)).must_equal [date("2026-12-05")]
      _(Planner::SeriesExclusion.where(series_id: rent.id).pluck(:excluded_on)).must_equal [date("2026-10-05")]
    end

    it "shares out a count: the new part has what is left" do
      counted = Planner::Series.create!(user:, title: "Course", starts_on: date("2026-10-05"), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO;COUNT=6")
      ok, = edit(counted, "2026-10-19", "following", title: "Course, part 2")
      _(ok).must_equal true
      newer = Planner::Series.where(user_id: user.id).where.not(id: counted.id).sole
      _(newer.rrule).must_equal "FREQ=WEEKLY;BYDAY=MO;COUNT=4"
      _(shown([counted], date("2026-10-01")..date("2026-12-31")).size).must_equal 6
    end

    it "changes the rule from the new day on" do
      form = repeat(rent, frequency: "weekly", weekdays: [])
      ok, = edit(rent, "2026-11-05", "following", form:)
      _(ok).must_equal true
      newer = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      _(newer.rrule).must_equal "FREQ=WEEKLY;BYDAY=TH"
    end

    it "gives the later parts of the chain the changes of the template, not a new rule" do
      edit(rent, "2026-12-05", "following", title: "Rent v2")
      later = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      ok, = edit(rent, "2026-11-05", "following", title: "Rent v3", notes: "x")
      _(ok).must_equal true
      _(later.reload.title).must_equal "Rent v3"
      _(later.rrule).must_equal "FREQ=MONTHLY;BYMONTHDAY=5"
    end

    it "changes the times of the template" do
      edit(rent, "2026-11-05", "following", start_time: "10:30", end_time: "12:00")
      newer = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      _([newer.start_time, newer.duration_minutes]).must_equal ["10:30", 90]
      _([rent.reload.start_time, rent.duration_minutes]).must_equal ["09:00", 60]
    end

    it "changes nothing, and splits nothing, when nothing was changed" do
      rent
      ok, = edit(rent, "2026-11-05", "following")
      _(ok).must_equal true
      _(Planner::Series.count).must_equal 1
      _(rent.reload.ends_on).must_be_nil
    end

    it "keeps an edited unsaved occurrence that moved to a day the rule does not give, as an event of its own" do
      weekly = Planner::Series.create!(user:, title: "Gym", starts_on: date("2026-10-05"), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60)
      ok, = edit(weekly, "2026-10-12", "following", day: "2026-10-13", title: "Gym, Tuesday")
      _(ok).must_equal true
      kept = Planner::Event.find_by!(title: "Gym, Tuesday")
      _([kept.series_id, kept.occurrence_on, kept.day]).must_equal [nil, nil, date("2026-10-13")]
    end

    it "does not restart a count, nor detach the events a delete of the past trashed, when the first one left is edited" do
      counted = Planner::Series.create!(user:, title: "Course", starts_on: date("2026-10-05"), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO;COUNT=6")
      early = counted.materialize(date("2026-10-05"))
      Planner::Recurrence::Delete.new(series: counted, item: counted.occurrence(date("2026-10-12")), scope: "past").call
      ok, = edit(counted.reload, "2026-10-19", "following", title: "Course, part 2")
      _(ok).must_equal true
      counted.reload
      _([counted.starts_on, counted.from_on, counted.title]).must_equal [date("2026-10-05"), date("2026-10-13"), "Course, part 2"]
      _(Planner::Event.find(early.id).series_id).must_equal counted.id
      _(counted.dates(date("2026-10-01")..date("2026-12-31")).size).must_equal 4
    end

    it "says why when the new day is taken by another event of the series, not what the database said" do
      weekly = Planner::Series.create!(user:, title: "Gym", starts_on: date("2026-10-05"), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO,WE", start_time: "18:00", duration_minutes: 60)
      weekly.materialize(date("2026-10-07"))
      weekly.materialize(date("2026-10-05"))
      item = weekly.occurrence(date("2026-10-05"))
      ok = Planner::Recurrence::Edit.new(series: weekly, item:, scope: "following", attributes: posted(item, day: "2026-10-07"), form: repeat(weekly)).call
      _(ok).must_equal false
      _(item.errors).must_include :day
      _(item.errors.full_messages.join).wont_include "UNIQUE"
      _(weekly.reload.starts_on).must_equal date("2026-10-05")
    end

    it "says the series changed meanwhile, and changes nothing" do
      stale = Planner::Series.find(rent.id)
      rent.update!(title: "Changed by someone else")
      item = stale.occurrence(date("2026-11-05"))
      ok = Planner::Recurrence::Edit.new(series: stale, item:, scope: "following", attributes: posted(item, title: "Mine"), form: repeat(stale)).call
      _(ok).must_equal false
      _(item.errors).must_include :base
      _(Planner::Series.count).must_equal 1
    end
  end

  describe "all" do
    it "changes the template of every part of the chain, and ignores the day" do
      edit(rent, "2026-12-05", "following", title: "Rent v2")
      ok, = edit(rent, "2026-11-05", "all", title: "Housing", day: "2026-11-20")
      _(ok).must_equal true
      _(Planner::Series.where(user_id: user.id).pluck(:title)).must_equal %w[Housing Housing]
      _(shown([rent]).first(3)).must_equal [["2026-10-05", "Housing"], ["2026-11-05", "Housing"], ["2026-12-05", "Housing"]]
    end

    it "changes only what was changed in the touched rows" do
      row = rent.materialize(date("2026-12-05")).tap { |event| event.update!(title: "Rent (late)") }
      edit(rent, "2026-11-05", "all", notes: "New note")
      _(row.reload.attributes.values_at("title", "notes")).must_equal ["Rent (late)", "New note"]
    end

    it "leaves an unsaved occurrence unsaved" do
      assert_no_difference "Planner::Event.count" do
        edit(rent, "2026-11-05", "all", title: "Housing")
      end
    end

    it "changes the times of the template and of the rows" do
      row = rent.materialize(date("2026-11-05"))
      edit(rent, "2026-12-05", "all", start_time: "10:00", end_time: "11:00")
      _([rent.reload.start_time, rent.duration_minutes]).must_equal ["10:00", 60]
      _(row.reload.start_time).must_equal "10:00"
    end

    it "saves the edited event too when the rule changes and the chain is put back together" do
      row = rent.materialize(date("2026-12-05"))
      ok, = edit(rent, "2026-12-05", "all", title: "Housing", form: repeat(rent, interval: 2))
      _(ok).must_equal true
      _(row.reload.title).must_equal "Housing"
      _(rent.reload.title).must_equal "Housing"
    end

    it "asks for a rule, in words, when none was given" do
      ["following", "all"].each do |scope|
        form = repeat(rent, frequency: "never")
        item = rent.occurrence(date("2026-11-05"))
        ok = Planner::Recurrence::Edit.new(series: rent, item:, scope:, attributes: posted(item, title: "x"), form:).call
        _(ok).must_equal false
        _(form.errors).must_include :frequency
      end
    end

    it "keeps the whole count of a shared-out series when the rule is changed for all of it" do
      counted = Planner::Series.create!(user:, title: "Course", starts_on: date("2026-10-05"), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO;COUNT=10")
      edit(counted, "2026-10-26", "following", title: "Course, part 2")
      later = Planner::Series.where(chain_id: counted.id).sole
      _(later.rrule).must_equal "FREQ=WEEKLY;BYDAY=MO;COUNT=7"
      ok, = edit(later, "2026-11-02", "all", form: repeat(later, interval: 2))
      _(ok).must_equal true
      _(counted.reload.rrule).must_equal "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;COUNT=10"
    end

    it "puts the chain back in one series when the rule changes" do
      row_old = rent.materialize(date("2026-10-05"))
      edit(rent, "2026-12-05", "following", day: "2026-12-10")
      later = Planner::Series.where(user_id: user.id).where.not(id: rent.id).sole
      row_new = later.materialize(date("2026-12-10"))
      ok, = edit(rent, "2026-11-05", "all", form: repeat(rent, interval: 2))
      _(ok).must_equal true
      _(Planner::Series.where(user_id: user.id).pluck(:id)).must_equal [rent.id]
      rent.reload
      _([rent.rrule, rent.starts_on, rent.ends_on, rent.chain_id]).must_equal ["FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=5", date("2026-10-05"), nil, nil]
      _(row_old.reload.series_id).must_equal rent.id
      _([row_new.reload.series_id, row_new.day]).must_equal [nil, date("2026-12-10")] # the 10th is not a day of the new rule
    end

    it "ends the whole series on a day before the occurrence that was edited, which stays as an event of its own" do
      ok, item = edit(rent, "2026-12-05", "all", form: repeat(rent, ends: "until", until_on: date("2026-11-20")))
      _(ok).must_equal true
      _(rent.reload.rrule).must_equal "FREQ=MONTHLY;BYMONTHDAY=5;UNTIL=20261120"
      _([item.persisted?, item.series_id, item.day]).must_equal [true, nil, date("2026-12-05")]
      _(rent.dates(date("2026-10-01")..date("2027-03-31")).map(&:to_s)).must_equal %w[2026-10-05 2026-11-05]
    end

    it "refuses a last day before the first day of the series, and changes nothing" do
      form = repeat(rent, ends: "until", until_on: date("2026-10-01"))
      ok, = edit(rent, "2026-12-05", "all", form:)
      _(ok).must_equal false
      _(form.errors.of_kind?(:until_on, :before_start)).must_equal true
      _(rent.reload.rrule).must_equal "FREQ=MONTHLY;BYMONTHDAY=5"
    end

    it "puts the chain back with the template of the part that was edited" do
      edit(rent, "2026-11-05", "following", title: "Rent and bills")
      later = Planner::Series.where(chain_id: rent.id).sole
      ok, = edit(later, "2026-12-05", "all", form: repeat(later, interval: 2))
      _(ok).must_equal true
      _(rent.reload.title).must_equal "Rent and bills"
    end

    it "forgets what was done in every event of the series when it stops tracking it" do
      rows = %w[2026-10-05 2026-11-05 2026-12-05].map { |day| rent.materialize(date(day)).tap { |row| row.mark_done(true) && row.save! } }
      ok, = edit(rent, "2026-11-05", "all", tracks_done: "0")
      _(ok).must_equal true
      _(rows.map { |row| Planner::Event.find(row.id).done? }).must_equal [false, false, false]
      _(rent.reload.tracks_done).must_equal 0
    end

    it "refuses an invalid occurrence, and changes nothing" do
      ok, item = edit(rent, "2026-11-05", "all", title: "x" * 300)
      _(ok).must_equal false
      _(item.errors).must_include :title
      _(rent.reload.title).must_equal "Rent"
    end
  end

  describe "after a catch-up" do
    before { travel_to Time.utc(2026, 12, 10, 12) }

    def made_days = Planner::Event.where(user_id: user.id, title: ["Rent", "Rent 2"]).order(:day).pluck(:day).map(&:to_s)

    it "gives the part a following edit starts the watermark of the one it split from" do
      rent.catch_up(date("2026-12-09"))
      ok, = edit(rent, "2026-11-05", "following", day: "2026-11-10", title: "Rent 2")
      _(ok).must_equal true
      newer = Planner::Series.where(chain_id: rent.id).sole
      _(newer.materialized_through).must_equal date("2026-12-09")
      before = made_days
      _(Planner::Series.catch_up(user, today: date("2026-12-10"))).must_equal 0
      _(made_days).must_equal before
      _(made_days.count("2026-11-10")).must_equal 1
    end

    it "leaves the past events a changed rule no longer gives as events of their own" do
      rent.catch_up(date("2026-12-09"))
      edit(rent, "2026-11-05", "following", day: "2026-11-10", title: "Rent 2")
      _(Planner::Event.where(user_id: user.id, title: "Rent", series_id: nil).order(:day).pluck(:day).map(&:to_s)).must_equal %w[2026-12-05]
    end

    it "keeps the past when all change the rule: no past day appears, none goes" do
      rent.catch_up(date("2026-12-09"))
      edit(rent, "2026-11-05", "following", title: "Rent 2")
      rent.reload.update_columns(materialized_through: date("2026-10-31"))
      newer = Planner::Series.where(chain_id: rent.id).sole
      ok, = edit(newer, "2026-12-05", "all", form: repeat(newer, interval: 2))
      _(ok).must_equal true
      _(rent.reload.materialized_through).must_equal date("2026-12-09")
      before = made_days
      _(Planner::Series.catch_up(user, today: date("2026-12-10"))).must_equal 0
      _(made_days).must_equal before
      _(made_days).must_equal %w[2026-10-05 2026-11-05 2026-12-05]
    end

    it "changes the titles of the past events when all change only the title" do
      rent.catch_up(date("2026-12-09"))
      ok, = edit(rent, "2026-12-05", "all", title: "Flat rent")
      _(ok).must_equal true
      _(Planner::Event.where(series_id: rent.id).pluck(:title).uniq).must_equal ["Flat rent"]
      _(Planner::Event.where(series_id: rent.id).count).must_equal 3
    end
  end
end
