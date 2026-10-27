require "test_helper"

describe Core::Selection do
  let(:admin) { users(:admin) }
  let(:session) { {} }
  let(:selection) { Core::Selection.new(session, admin) }
  let(:ids) { ->(*labels) { labels.map { |label| core_entities(label).id } } }

  it "starts empty and asks nothing of the database for it" do
    _(selection.ids).must_equal []
    _(selects { selection.entries }).must_be_empty
  end

  it "keeps up to two, in the order they were chosen, in the session" do
    one, two = ids.call(:dentist, :holiday)
    _(selection.add(one)).must_equal true
    _(selection.add(two)).must_equal true
    _(Core::Selection.new(session, admin).ids).must_equal [one, two]
  end

  it "takes the same record once" do
    one = core_entities(:dentist).id
    selection.add(one)
    _(selection.add(one)).must_equal true
    _(selection.ids).must_equal [one]
  end

  it "refuses a third" do
    one, two, three = ids.call(:dentist, :holiday, :rent_paid)
    selection.add(one)
    selection.add(two)
    _(selection).must_be :full?
    _(selection.add(three)).must_equal false
    _(selection.ids).must_equal [one, two]
  end

  it "removes one, or all" do
    one, two = ids.call(:dentist, :holiday)
    selection.add(one)
    selection.add(two)
    selection.remove(one)
    _(selection.ids).must_equal [two]
    selection.clear
    _(selection.ids).must_equal []
  end

  it "gives the entities with their records, as chosen" do
    one, two = ids.call(:holiday, :dentist)
    selection.add(one)
    selection.add(two)
    _(selection.entries.map { |entity| entity.record.title }).must_equal ["Bank holiday", "Dentist"]
  end

  it "drops what has gone to the trash, is gone, or is someone else's" do
    kept, trashed, foreign = ids.call(:dentist, :trashed_event, :other_users_event)
    session[Core::Selection::KEY] = [kept, trashed]
    _(selection.entries.map(&:id)).must_equal [kept]
    _(selection.ids).must_equal [kept]
    session[Core::Selection::KEY] = [foreign, 999_999]
    _(Core::Selection.new(session, admin).entries).must_be_empty
  end

  it "drops an entity whose record is missing, so a page never fails on it" do
    one, two = ids.call(:holiday, :dentist)
    ActiveRecord::Base.connection.execute("DELETE FROM planner_items WHERE id = #{one}")
    session[Core::Selection::KEY] = [one, two]
    selection = Core::Selection.new(session, admin)
    _(selection.entries.map(&:id)).must_equal [two]
    _(selection.ids).must_equal [two]
  end

  it "survives junk in the session" do
    session[Core::Selection::KEY] = ["x", nil, 5, 5, 6, 7]
    _(Core::Selection.new(session, admin).ids).must_equal [5, 6]
  end
end
