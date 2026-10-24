require "test_helper"

describe "db/seeds.rb" do
  def table_counts
    connection = ActiveRecord::Base.connection
    connection.tables.sort.to_h { |table| [table, connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}")] }
  end

  # Seeds only create demo data in development, so run them as if in development.
  def load_seed_as_development
    original = Rails.env
    Rails.env = "development"
    Rails.application.load_seed
  ensure
    Rails.env = original
  end

  it "can run twice without changing the database" do
    load_seed_as_development
    first = table_counts
    load_seed_as_development
    _(table_counts).must_equal first
    assert User.exists?(email_address: "demo-admin@example.com")
  end

  it "puts the demo events around the day it runs, however long ago the data was made" do
    load_seed_as_development
    travel_to 10.days.from_now do
      load_seed_as_development
      demo = User.find_by!(email_address: "demo-user@example.com")
      _(Planner::Event.owned_by(demo).find_by!(title: "Dentist").day).must_equal Date.current + 2
    end
  end

  it "gives the demo user three overlapping events today, to try the week view" do
    load_seed_as_development
    demo = User.find_by!(email_address: "demo-user@example.com")
    today = Planner::Event.owned_by(demo).where(day: Date.current).where.not(starts_at: nil).order(:starts_at).to_a
    _(today.size).must_be :>=, 3
    _(today.count { |event| event.starts_at < today.first.ends_at }).must_be :>=, 3
  end

  it "gives the demo user tasks around today, to try the schedule" do
    load_seed_as_development
    demo = User.find_by!(email_address: "demo-user@example.com")
    tasks = Planner::Task.owned_by(demo).kept
    _(tasks.count).must_equal 8
    _(tasks.where(day: Date.current).count).must_equal 4
    _(tasks.where(state: "abandoned").count).must_equal 2
    _(tasks.where.not(done_at: nil)).wont_be_empty
  end

  it "creates demo events for the demo user only, one set however often it runs" do
    load_seed_as_development
    load_seed_as_development
    demo = User.find_by!(email_address: "demo-user@example.com")
    _(Planner::Event.owned_by(demo).kept.count).must_equal 8
    _(Planner::Event.owned_by(demo).where.not(starts_at: nil)).wont_be_empty
    _(Planner::Event.owned_by(demo).where(tracks_done: 1)).wont_be_empty
    _(Planner::Event.where.not(user: demo).count).must_equal Planner::Event.where(user_id: users(:admin).id).count + Planner::Event.where(user_id: users(:other_admin).id).count
  end

  it "gives the demo user a todo list in order, with a priority mix and one done, one set however often it runs" do
    load_seed_as_development
    load_seed_as_development
    demo = User.find_by!(email_address: "demo-user@example.com")
    todos = Planner::Todo.owned_by(demo).kept.in_order
    _(todos.map(&:position)).must_equal (1..6).to_a
    _(todos.first.title).must_equal "Fix the leaking tap"
    _(todos.map(&:priority).uniq).must_include "urgent"
    _(todos.count(&:done?)).must_equal 1
  end

  it "marks a few demo events and tasks with a priority" do
    load_seed_as_development
    demo = User.find_by!(email_address: "demo-user@example.com")
    _(Planner::Item.owned_by(demo).where.not(priority: 1).count).must_be :>=, 4
  end

  it "puts one event, one task and one todo of the demo user in the trash, at different ages, again on every run" do
    load_seed_as_development
    demo = User.find_by!(email_address: "demo-user@example.com")
    trashed = Planner::Item.owned_by(demo).trashed.eager_load(:entity).order("core_entities.deleted_at").to_a
    _(trashed.map(&:class)).must_equal [Planner::Task, Planner::Event, Planner::Todo]
    load_seed_as_development
    _(Planner::Item.owned_by(demo).trashed.count).must_equal 3
    _(Core::Entity.purgeable.where(user: demo)).must_be :empty?
  end
end
