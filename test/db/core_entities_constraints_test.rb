require "test_helper"

describe "core_entities constraints" do
  let(:connection) { ActiveRecord::Base.connection }

  def insert_entity(user_id: users(:member).id, record_type: "Planner::Item")
    connection.execute("INSERT INTO core_entities (user_id, record_type, created_at, updated_at) VALUES (#{connection.quote(user_id)},
      #{connection.quote(record_type)}, '2026-01-01', '2026-01-01')")
  end

  def unique_indexes = connection.indexes(:core_entities).select(&:unique).map(&:columns)

  it "has the unique keys that records and links reference" do
    _(unique_indexes).must_include %w[id user_id]
    _(unique_indexes).must_include %w[id record_type]
    _(unique_indexes).must_include %w[id user_id record_type]
  end

  it "needs an owner and a record type" do
    _ { insert_entity(user_id: nil) }.must_raise ActiveRecord::NotNullViolation
    _ { insert_entity(record_type: nil) }.must_raise ActiveRecord::NotNullViolation
  end

  it "refuses an owner that does not exist" do
    _ { insert_entity(user_id: 999_999) }.must_raise ActiveRecord::InvalidForeignKey
  end

  it "goes with its user (ON DELETE CASCADE)" do
    insert_entity
    connection.execute("DELETE FROM users WHERE id = #{users(:member).id}")
    _(Core::Entity.where(user_id: users(:member).id)).must_be_empty
  end

  it "leaves no foreign key violation behind" do
    insert_entity
    _(connection.select_rows("PRAGMA foreign_key_check")).must_be_empty
  end
end
