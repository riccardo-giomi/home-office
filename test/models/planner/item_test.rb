require "test_helper"

describe Planner::Item do
  describe ".kind" do
    it "names the type in lower case" do
      _(Planner::Event.kind).must_equal "event"
      _(Planner::Task.kind).must_equal "task"
    end
  end
end
