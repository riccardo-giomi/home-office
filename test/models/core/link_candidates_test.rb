require "test_helper"

describe Core::LinkCandidates do
  let(:admin) { users(:admin) }
  let(:kind) { ->(key) { Core::Modules.linkable_kind(key) } }

  def search(key, term = nil, except: nil) = Core::LinkCandidates.new(user: admin, kind: kind.call(key), term:, except_id: except)

  it "lists the user's kept records of the kind, by title" do
    titles = search("task").results.map(&:title)
    _(titles).must_equal titles.sort
    _(titles).must_include "Pay the rent"
    _(titles).wont_include planner_items(:trashed_task).title
    _(titles).wont_include planner_items(:other_users_task).title
    _(search("task").results.map(&:class).uniq).must_equal [Planner::Task]
  end

  it "narrows by a part of the title, whatever the case" do
    _(search("task", "RENT").results.map(&:title)).must_equal ["Pay the rent"]
  end

  it "leaves out the record being linked" do
    _(search("task", "rent", except: core_entities(:pay_rent_task).id).results).must_be_empty
  end

  it "takes % _ and \\ as the letters they are" do
    planner_items(:buy_stamps_task).update_columns(title: "100% sure_thing \\ end")
    _(search("task", "%").results.map(&:title)).must_equal ["100% sure_thing \\ end"]
    _(search("task", "_t").results.map(&:title)).must_equal ["100% sure_thing \\ end"]
    _(search("task", "\\").results.map(&:title)).must_equal ["100% sure_thing \\ end"]
    _(search("task", "r_e").results).must_be_empty
  end

  it "gives ten and says there are more" do
    12.times { |n| Planner::Todo.create!(user: admin, title: "Bulk #{n}") }
    found = search("todo", "Bulk")
    _(found.results.size).must_equal 10
    _(found).must_be :more?
    _(search("todo", "Bulk 1").results.size).must_equal 3
    _(search("todo", "Bulk 1")).wont_be :more?
  end
end
