require "test_helper"

describe Planner::Trash do
  let(:user) { users(:admin) }

  it "counts what is trashed for each kind, zeros included, for this user only" do
    _(Planner::Trash.new(user).counts).must_equal({"event" => 2, "task" => 1, "todo" => 1})
    _(Planner::Trash.new(users(:member)).counts).must_equal({"event" => 0, "task" => 0, "todo" => 0})
    _(Planner::Trash.new(users(:other_admin)).counts).must_equal({"event" => 1, "task" => 0, "todo" => 0})
  end

  it "adds up to a total" do
    _(Planner::Trash.new(user).total).must_equal 4
    _(Planner::Trash.new(users(:member)).total).must_equal 0
  end

  it "lists the newest trashed first, kept items never" do
    _(Planner::Trash.new(user).items.map(&:title)).must_equal ["Thrown away task", "Thrown away event", "Thrown away todo", "Long gone event"]
  end

  it "filters by kind, and treats an unknown kind as all" do
    _(Planner::Trash.new(user, type: "task").items.map(&:title)).must_equal ["Thrown away task"]
    _(Planner::Trash.new(user, type: "event").items.count).must_equal 2
    _(Planner::Trash.new(user, type: "banana").items.count).must_equal 4
    _(Planner::Trash.new(user, type: "banana").type).must_be_nil
    _(Planner::Trash.new(user, type: "todo").type).must_equal "todo"
  end

  it "empties the whole trash of the user, and only that" do
    items = Planner::Item.count
    _(Planner::Trash.new(user, type: "task").empty!).must_equal 4
    _(Planner::Item.count).must_equal items - 4
    _(Planner::Item.owned_by(user).trashed.count).must_equal 0
    _(Planner::Item.owned_by(users(:other_admin)).trashed.count).must_equal 1
    _(Planner::Item.owned_by(user).kept.count).must_be :>, 0
  end

  it "reports nothing to restore in an empty trash" do
    _(Planner::Trash.new(users(:member)).items).must_be :empty?
  end

  describe "with series" do
    let(:member) { users(:member) }
    let(:gym) do
      Planner::Series.create!(user: member, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60)
    end

    def trash_gym(row_on: "2026-10-12")
      gym.materialize(Date.parse(row_on))
      Planner::Recurrence::Delete.new(series: gym, item: gym.occurrence(Date.new(2026, 10, 19)), scope: "all").call
    end

    it "counts a series as one event, whatever it holds, and hides the events trashed with it" do
      Planner::Event.create!(user: member, title: "Alone", day: Date.new(2026, 10, 7)).trash
      trash_gym
      trash = Planner::Trash.new(member)
      _(trash.counts).must_equal({"event" => 2, "task" => 0, "todo" => 0})
      _(trash.total).must_equal 2
      _(trash.items.map(&:title)).must_equal ["Alone"]
    end

    it "lists the series on their own, in all and in events, not in tasks or todos" do
      trash_gym
      _(Planner::Trash.new(member).series_groups.map { |group| group.first.title }).must_equal ["Gym"]
      _(Planner::Trash.new(member, type: "event").series_groups.size).must_equal 1
      _(Planner::Trash.new(member, type: "task").series_groups).must_be :empty?
      _(Planner::Trash.new(member, type: "todo").series_groups).must_be :empty?
    end

    it "lists an event trashed on its own before the series went, so it can be restored on its own" do
      row = gym.materialize(Date.new(2026, 10, 26)).tap(&:trash)
      sleep 0.01
      trash_gym
      _(Planner::Trash.new(member).items.map(&:id)).must_equal [row.id]
      _(Planner::Trash.new(member).counts["event"]).must_equal 2
    end

    it "empties the series too, with their events, and counts them" do
      trash_gym
      Planner::Event.create!(user: member, title: "Alone", day: Date.new(2026, 10, 7)).trash
      _(Planner::Trash.new(member).empty!).must_equal 2
      _(Planner::Series.where(id: gym.id)).must_be :empty?
      _(Planner::Event.where(user_id: member.id)).must_be :empty?
    end

    it "does not touch another user's series" do
      trash_gym
      theirs = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY")
      Planner::Series.where(id: theirs.id).update_all(deleted_at: Time.current)
      Planner::Trash.new(member).empty!
      _(Planner::Series.where(id: theirs.id)).must_be :exists?
    end
  end
end
