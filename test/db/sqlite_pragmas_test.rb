require "test_helper"

describe "SQLite configuration" do
  let(:connection) { ActiveRecord::Base.connection }

  it "enforces foreign keys" do
    _(connection.select_value("PRAGMA foreign_keys")).must_equal 1
  end

  it "has no foreign key violations" do
    _(connection.select_rows("PRAGMA foreign_key_check")).must_be_empty
  end
end
