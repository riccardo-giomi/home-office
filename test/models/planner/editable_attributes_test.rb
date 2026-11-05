require "test_helper"

describe "Planner::Item.editable_attributes" do
  it "lists what a person may set on each kind, never ownership, state or done_at" do
    _(Planner::Todo.editable_attributes).must_equal %i[title notes priority]
    _(Planner::Task.editable_attributes).must_equal %i[title notes priority day start_time end_time]
    _(Planner::Event.editable_attributes).must_equal %i[title notes priority day start_time end_time tracks_done]
  end
end
