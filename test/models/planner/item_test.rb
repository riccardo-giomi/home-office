require "test_helper"

describe Planner::Item do
  describe ".kind" do
    it "names the type in lower case" do
      _(Planner::Event.kind).must_equal "event"
      _(Planner::Task.kind).must_equal "task"
    end
  end

  describe "as a record to link" do
    it "is known by its kind, labelled by its title" do
      _(planner_items(:dentist).for_links.kind).must_equal "event"
      _(planner_items(:pay_rent_task).for_links.kind).must_equal "task"
      _(planner_items(:water_plants_todo).for_links.kind).must_equal "todo"
      _(planner_items(:dentist).for_links.label).must_equal "Dentist"
    end

    it "says nothing about an active item, and in words what is not" do
      I18n.with_locale(:en) do
        _(planner_items(:pay_rent_task).for_links.status).must_be_nil
        _(planner_items(:abandoned_task).for_links.status).must_equal "Abandoned"
        _(planner_items(:cancelled_event).for_links.status).must_equal "Cancelled"
        _(planner_items(:done_task).for_links.status).must_equal "Done"
      end
    end

    it "has the day of an item that has one of its own, and none for a todo" do
      _(planner_items(:dentist).for_links.day).must_equal planner_items(:dentist).day
      _(planner_items(:water_plants_todo).for_links.day).must_be_nil
    end
  end

  describe "#change_state" do
    cases = [
      [:pay_rent_task, "abandoned", true, "abandoned"],
      [:pay_rent_task, "cancelled", false, "active"],
      [:dentist, "cancelled", true, "cancelled"],
      [:dentist, "abandoned", true, "abandoned"],
      [:abandoned_task, "active", true, "active"],
      [:cancelled_event, "active", true, "active"],
      [:dentist, "active", false, "active"],
      [:dentist, "banana", false, "active"],
      [:dentist, nil, false, "active"]
    ]

    cases.each do |fixture, to, result, state|
      it "#{fixture} to #{to.inspect} answers #{result} and ends #{state}" do
        item = planner_items(fixture)
        _(item.change_state(to)).must_equal result
        _(item.reload.state).must_equal state
      end
    end
  end

  describe "#state_changes" do
    it "lists the states an item can move to" do
      _(planner_items(:pay_rent_task).state_changes).must_equal %w[abandoned]
      _(planner_items(:dentist).state_changes).must_equal %w[abandoned cancelled]
      _(planner_items(:abandoned_task).state_changes).must_equal %w[active]
    end
  end

  describe "priority" do
    let(:user) { users(:member) }

    def build(**attrs) = Planner::Event.new({user:, title: "Dentist", day: Date.new(2026, 10, 7)}.merge(attrs))

    it "is normal by default" do
      _(build.priority).must_equal "normal"
    end

    it "takes low, high and urgent" do
      %w[low high urgent].each { |level| _(build(priority: level).tap(&:save!).reload.priority).must_equal level }
    end

    it "is invalid, not an exception, when unknown" do
      item = build(priority: "9")
      _(item.valid?).must_equal false
      _(item.errors[:priority]).wont_be_empty
    end
  end

  describe "position" do
    let(:user) { users(:member) }
    let(:other) { users(:other_admin) }

    def create(klass, owner, title) = klass.create!(user: owner, title:, day: Date.new(2026, 10, 7))

    it "counts from 1 for each user and each type, new items at the end" do
      Planner::Item.where(user: [user, other]).delete_all
      first = create(Planner::Event, user, "One")
      second = create(Planner::Event, user, "Two")
      task = create(Planner::Task, user, "Task")
      foreign = create(Planner::Event, other, "Foreign")
      _([first, second, task, foreign].map(&:position)).must_equal [1, 2, 1, 1]
    end
  end
end
