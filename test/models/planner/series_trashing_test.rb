require "test_helper"

describe "Planner::Series in the trash" do
  let(:user) { users(:member) }

  def series(title = "Gym", **attrs)
    Planner::Series.create!({user:, title:, starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60}.merge(attrs))
  end

  def date(text) = Date.parse(text)

  # Delete all, as a user does it
  def trash_all(one, on = "2026-10-12")
    Planner::Recurrence::Delete.new(series: one, item: one.occurrence(date(on)), scope: "all").call
  end

  describe ".trash_groups" do
    it "lists what went to the trash together as one, newest first, for the user only" do
      first = series("First")
      second = series("Second")
      travel_to(2.days.ago) { trash_all(first) }
      trash_all(second)
      series("Theirs", user: users(:other_admin)).tap { |theirs| trash_all(theirs) }
      series("Kept")
      groups = Planner::Series.trash_groups(user)
      _(groups.map { |group| group.first.title }).must_equal %w[Second First]
      _(groups.first.deleted_at).must_equal second.reload.deleted_at
    end

    it "makes one group of the parts of a chain trashed by one action, and two of parts trashed apart" do
      head = series("Rent", rrule: "FREQ=MONTHLY;BYMONTHDAY=5")
      Planner::Recurrence::Edit.new(series: head, item: head.occurrence(date("2026-12-05")), scope: "following", form: Planner::Recurrence::Form.from_rule(head.rule),
        attributes: {title: "Rent 2", notes: "", priority: "normal", tracks_done: "0", day: "2026-12-05", start_time: "18:00", end_time: "19:00"}).call
      tail = Planner::Series.where(chain_id: head.id).sole
      trash_all(head, "2026-11-05")
      groups = Planner::Series.trash_groups(user)
      _(groups.size).must_equal 1
      _(groups.first.segments.map(&:id)).must_equal [head.id, tail.id]
      _(groups.first.id).must_equal head.id
    end
  end

  describe "#restore_group" do
    it "brings back the parts and the events trashed with them, not what was trashed before" do
      gym = series
      early = gym.materialize(date("2026-10-12"))
      earlier = gym.materialize(date("2026-10-19")).tap(&:trash)
      sleep 0.01
      trash_all(gym)
      gym.reload.restore_group
      _(gym.reload).wont_be :trashed?
      _(Planner::Event.includes(:entity).find(early.id)).wont_be :trashed?
      _(Planner::Event.includes(:entity).find(earlier.id)).must_be :trashed?
    end

    it "puts the series back among those that are shown" do
      gym = series
      trash_all(gym)
      _(Planner::Occurrences.for(user, date("2026-10-01")..date("2026-10-31"))).must_be :empty?
      gym.reload.restore_group
      _(Planner::Occurrences.for(user, date("2026-10-01")..date("2026-10-31")).size).must_equal 4
    end
  end

  describe ".purge" do
    it "removes the trashed events, detaches the live ones, then the series and its exclusions" do
      gym = series
      gym.exclusions.create!(user_id: user.id, excluded_on: date("2026-10-26"))
      trashed_row = gym.materialize(date("2026-10-12"))
      live_row = gym.materialize(date("2026-10-19"))
      trash_all(gym)
      Planner::Event.includes(:entity).find(live_row.id).restore
      Planner::Series.purge(Planner::Series.where(id: gym.id))
      _(Planner::Series.where(id: gym.id)).must_be :empty?
      _(Planner::SeriesExclusion.where(series_id: gym.id)).must_be :empty?
      _(Planner::Event.where(id: trashed_row.id)).must_be :empty?
      detached = Planner::Event.find(live_row.id)
      _([detached.series_id, detached.occurrence_on]).must_equal [nil, nil]
    end

    it "keeps the chain together when its first part goes: the next one becomes the first" do
      head = series("Rent", rrule: "FREQ=MONTHLY;BYMONTHDAY=5")
      Planner::Recurrence::Edit.new(series: head, item: head.occurrence(date("2026-11-05")), scope: "following", form: Planner::Recurrence::Form.from_rule(head.rule),
        attributes: {title: "Rent 2", notes: "", priority: "normal", tracks_done: "0", day: "2026-11-05", start_time: "18:00", end_time: "19:00"}).call
      middle = Planner::Series.find_by!(chain_id: head.id)
      Planner::Recurrence::Edit.new(series: middle, item: middle.occurrence(date("2026-12-05")), scope: "following", form: Planner::Recurrence::Form.from_rule(middle.rule),
        attributes: {title: "Rent 3", notes: "", priority: "normal", tracks_done: "0", day: "2026-12-05", start_time: "18:00", end_time: "19:00"}).call
      second, third = Planner::Series.where(chain_id: head.id).order(:starts_on).to_a
      Planner::Series.where(id: head.id).update_all(deleted_at: Time.current)
      Planner::Series.purge(Planner::Series.where(id: head.id))
      _(second.reload.chain_id).must_be_nil
      _(third.reload.chain_id).must_equal second.id
      _(second.chain.map(&:id)).must_equal [second.id, third.id]
    end

    it "takes only what has been in the trash past its time" do
      old = series("Old")
      recent = series("Recent")
      trash_all(old)
      trash_all(recent)
      Planner::Series.where(id: old.id).update_all(deleted_at: 40.days.ago)
      Planner::Series.purge_expired
      _(Planner::Series.where(id: old.id)).must_be :empty?
      _(Planner::Series.where(id: recent.id)).must_be :exists?
    end

    it "is done by the purge job, through the module's manifest" do
      old = series("Old")
      trash_all(old)
      Planner::Series.where(id: old.id).update_all(deleted_at: 40.days.ago)
      Core::PurgeTrashJob.perform_now
      _(Planner::Series.where(id: old.id)).must_be :empty?
    end
  end
end
