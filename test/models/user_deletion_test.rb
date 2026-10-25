require "test_helper"

describe "deleting a user for good" do
  it "takes everything of theirs and nothing of anyone else's" do
    member = users(:member)
    Planner::Todo.create!(user: member, title: "Mine")
    Planner::Event.create!(user: member, title: "Kept event", day: Date.new(2026, 10, 7))
    Planner::Event.create!(user: member, title: "Trashed event", day: Date.new(2026, 10, 7)).trash
    member.sessions.create!
    Core::Link.connect(member, Planner::Todo.where(user_id: member.id).first.id, Planner::Event.where(user_id: member.id).first.id)
    other_links = Core::Link.where.not(user_id: member.id).count
    others = Planner::Item.where.not(user_id: member.id).count
    other_sessions = Session.where.not(user_id: member.id).count

    member.destroy!

    _(Planner::Item.where(user_id: member.id).count).must_equal 0
    _(Session.where(user_id: member.id).count).must_equal 0
    _(Core::Link.where(user_id: member.id).count).must_equal 0
    _(Core::Link.where.not(user_id: member.id).count).must_equal other_links
    _(Planner::Item.where.not(user_id: member.id).count).must_equal others
    _(Session.where.not(user_id: member.id).count).must_equal other_sessions
    _(ActiveRecord::Base.connection.select_rows("PRAGMA foreign_key_check")).must_be :empty?
  end

  it "is allowed only for a user who is deactivated" do
    _(users(:retired)).must_be :removable?
    _(users(:member)).wont_be :removable?
  end
end
