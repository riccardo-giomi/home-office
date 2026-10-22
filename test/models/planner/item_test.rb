require "test_helper"

describe Planner::Item do
  describe ".kind" do
    it "names the type in lower case" do
      _(Planner::Event.kind).must_equal "event"
      _(Planner::Task.kind).must_equal "task"
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
end
