require "test_helper"

describe "planner_items constraints" do
  let(:connection) { ActiveRecord::Base.connection }
  let(:user) { users(:member) }

  # Raw SQL on purpose: the model validations must not be what rejects the row. An item needs its entity first.
  def insert_entity(user_id: user.id, record_type: "Planner::Item")
    connection.execute("INSERT INTO core_entities (user_id, record_type, created_at, updated_at) VALUES (#{user_id}, '#{record_type}', '2026-01-01', '2026-01-01')")
    connection.select_value("SELECT last_insert_rowid()")
  end

  def insert_item(type: "Planner::Event", title: "Dentist", day: "'2026-10-07'", starts_at: "NULL", ends_at: "NULL",
    time_zone: "NULL", state: "active", tracks_done: 0, done_at: "NULL", user_id: user.id, id: nil, record_type: "Planner::Item")
    id ||= insert_entity(user_id:)
    connection.execute(<<~SQL)
      INSERT INTO planner_items (id, user_id, record_type, type, title, day, starts_at, ends_at, time_zone, state, tracks_done, done_at, created_at, updated_at)
      VALUES (#{id}, #{user_id}, '#{record_type}', '#{type}', '#{title}', #{day}, #{starts_at}, #{ends_at}, #{time_zone}, '#{state}', #{tracks_done}, #{done_at}, '2026-01-01', '2026-01-01')
    SQL
  end

  def rejects(constraint, **attrs)
    error = _ { insert_item(**attrs) }.must_raise ActiveRecord::StatementInvalid
    _(error.message).must_include constraint
  end

  it "accepts an all-day and a timed event" do
    assert_nothing_raised do
      insert_item
      insert_item(starts_at: "'2026-10-07 07:30:00'", ends_at: "'2026-10-07 08:00:00'", time_zone: "'Europe/Rome'")
    end
  end

  it "allows events and tasks, and nothing else yet" do
    assert_nothing_raised { insert_item(type: "Planner::Task", tracks_done: 1) }
    rejects "chk_planner_items_type", type: "Planner::Todo", tracks_done: 1
  end

  it "requires a task to track done" do
    rejects "chk_planner_items_done_always", type: "Planner::Task", tracks_done: 0
    assert_nothing_raised { insert_item(type: "Planner::Event", tracks_done: 0) }
  end

  it "keeps cancelled for events" do
    rejects "chk_planner_items_cancelled_events", type: "Planner::Task", tracks_done: 1, state: "cancelled"
  end

  it "rejects a blank or too long title" do
    rejects "chk_planner_items_title", title: "   "
    rejects "chk_planner_items_title", title: "a" * 256
  end

  it "rejects a day that is not a plain date" do
    rejects "chk_planner_items_day_format", day: "'2026-10-07 10:00:00'"
  end

  it "requires a day" do
    rejects "chk_planner_items_day_required", day: "NULL"
  end

  it "keeps start, end and zone together" do
    rejects "chk_planner_items_times_paired", starts_at: "'2026-10-07 07:30:00'", time_zone: "'Europe/Rome'"
    rejects "chk_planner_items_times_paired", time_zone: "'Europe/Rome'"
    rejects "chk_planner_items_times_paired", starts_at: "'2026-10-07 07:30:00'", ends_at: "'2026-10-07 08:00:00'"
  end

  it "needs the end strictly after the start" do
    rejects "chk_planner_items_window_order", starts_at: "'2026-10-07 07:30:00'", ends_at: "'2026-10-07 07:30:00'", time_zone: "'Europe/Rome'"
    rejects "chk_planner_items_window_order", starts_at: "'2026-10-07 07:30:00'", ends_at: "'2026-10-07 07:00:00'", time_zone: "'Europe/Rome'"
  end

  it "rejects an unknown state, and the replaced state does not exist" do
    rejects "chk_planner_items_state", state: "paused"
    rejects "chk_planner_items_state", state: "replaced"
  end

  it "allows cancelled for events" do
    assert_nothing_raised { insert_item(state: "cancelled") }
  end

  it "keeps tracks_done to 0 or 1" do
    rejects "chk_planner_items_tracks_done", tracks_done: 2
  end

  it "allows done_at only when the event tracks done" do
    rejects "chk_planner_items_done_tracked", done_at: "'2026-10-07 08:00:00'"
    insert_item(tracks_done: 1, done_at: "'2026-10-07 08:00:00'")
  end

  describe "the entity" do
    it "refuses an item without an entity" do
      _ { insert_item(id: 99_999) }.must_raise ActiveRecord::InvalidForeignKey
    end

    it "refuses an item whose user is not its entity's user" do
      id = insert_entity(user_id: users(:admin).id)
      _ { insert_item(id:, user_id: user.id) }.must_raise ActiveRecord::InvalidForeignKey
    end

    it "refuses a record type other than the item's" do
      id = insert_entity(record_type: "Document")
      error = _ { insert_item(id:, record_type: "Document") }.must_raise ActiveRecord::StatementInvalid
      _(error.message).must_include "chk_planner_items_record_type"
    end

    it "goes with its entity (ON DELETE CASCADE)" do
      id = insert_entity
      insert_item(id:)
      connection.execute("DELETE FROM core_entities WHERE id = #{id}")
      _(connection.select_value("SELECT COUNT(*) FROM planner_items WHERE id = #{id}")).must_equal 0
    end

    it "goes with its user, through the entity" do
      insert_item
      connection.execute("DELETE FROM users WHERE id = #{user.id}")
      _(connection.select_value("SELECT COUNT(*) FROM planner_items WHERE user_id = #{user.id}")).must_equal 0
      _(connection.select_value("SELECT COUNT(*) FROM core_entities WHERE user_id = #{user.id}")).must_equal 0
      _(connection.select_all("PRAGMA foreign_key_check")).must_be_empty
    end
  end
end
