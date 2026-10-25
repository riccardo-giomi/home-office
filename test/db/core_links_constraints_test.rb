require "test_helper"

# Validations bypassed on purpose: the schema alone must refuse these
describe "core_links constraints" do
  let(:admin) { users(:admin) }

  def insert_link(first, second, user: admin)
    ids = [first, second].map { |label| label.is_a?(Integer) ? label : core_entities(label).id }
    Core::Link.insert_all!([{first_entity_id: ids[0], second_entity_id: ids[1], user_id: user.id, created_at: Time.current}])
  end

  def ordered(first, second) = [core_entities(first).id, core_entities(second).id].sort

  it "accepts an ordered pair of one user's entities" do
    low, high = ordered(:holiday, :rent_paid)
    insert_link(low, high)
    _(Core::Link.where(first_entity_id: low, second_entity_id: high).count).must_equal 1
  end

  it "refuses a pair out of order" do
    low, high = ordered(:holiday, :rent_paid)
    _ { insert_link(high, low) }.must_raise ActiveRecord::CheckViolation
  end

  it "refuses a link to itself" do
    id = core_entities(:holiday).id
    _ { insert_link(id, id) }.must_raise ActiveRecord::CheckViolation
  end

  it "refuses an end that belongs to another user" do
    low, high = ordered(:holiday, :other_users_event)
    _ { insert_link(low, high) }.must_raise ActiveRecord::InvalidForeignKey
  end

  it "refuses the same pair twice" do
    low, high = ordered(:holiday, :rent_paid)
    insert_link(low, high)
    _ { insert_link(low, high) }.must_raise ActiveRecord::RecordNotUnique
  end

  it "goes with either end when it is purged" do
    low, high = ordered(:holiday, :expired_event)
    insert_link(low, high)
    Core::Entity.purge_expired
    _(Core::Link.where(first_entity_id: low, second_entity_id: high)).must_be_empty
    _(Planner::Item.exists?(core_entities(:holiday).id)).must_equal true
  end

  it "goes with its user" do
    low, high = ordered(:holiday, :rent_paid)
    insert_link(low, high)
    ActiveRecord::Base.connection.execute("DELETE FROM users WHERE id = #{admin.id}")
    _(Core::Link.where(user_id: admin.id)).must_be_empty
  end

  it "leaves no foreign key violation behind" do
    low, high = ordered(:holiday, :rent_paid)
    insert_link(low, high)
    _(ActiveRecord::Base.connection.select_rows("PRAGMA foreign_key_check")).must_be_empty
  end
end
