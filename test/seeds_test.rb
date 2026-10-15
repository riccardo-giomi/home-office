require "test_helper"

describe "db/seeds.rb" do
  def table_counts
    connection = ActiveRecord::Base.connection
    connection.tables.sort.to_h do |table|
      [table,
        connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}")]
    end
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
end
