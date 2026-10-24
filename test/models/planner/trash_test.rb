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
end
