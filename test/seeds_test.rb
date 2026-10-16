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

  it "creates demo events for the demo user only, one set however often it runs" do
    load_seed_as_development
    load_seed_as_development
    demo = User.find_by!(email_address: "demo-user@example.com")
    _(Planner::Event.owned_by(demo).count).must_equal 4
    _(Planner::Event.owned_by(demo).where.not(starts_at: nil)).wont_be_empty
    _(Planner::Event.owned_by(demo).where(tracks_done: 1)).wont_be_empty
    _(Planner::Event.where.not(user: demo).count).must_equal Planner::Event.where(user_id: users(:admin).id).count + Planner::Event.where(user_id: users(:other_admin).id).count
  end
end
