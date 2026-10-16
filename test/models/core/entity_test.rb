require "test_helper"

describe Core::Entity do
  def new_event(**attributes) = Planner::Event.new({user: users(:member), title: "Dentist", day: Date.new(2026, 10, 7)}.merge(attributes))

  it "is created with its record, with the record's id, owner and base class" do
    event = new_event
    assert_difference "Core::Entity.count", 1 do
      event.save!
    end
    entity = Core::Entity.find(event.id)
    _([entity.user_id, entity.record_type]).must_equal [users(:member).id, "Planner::Item"]
  end

  it "gives back the record, as the subclass, when it is preloaded" do
    event = new_event.tap(&:save!)
    _(Core::Entity.includes(:record).find(event.id).record).must_be_instance_of Planner::Event
  end

  it "is not touched when its record changes type" do
    event = new_event.tap(&:save!)
    Planner::Item.where(id: event.id).update_all(type: "Planner::Event")
    _(Core::Entity.where(id: event.id).pluck(:record_type)).must_equal ["Planner::Item"]
  end

  it "needs no loading of the entity to create, find and update a record (strict loading)" do
    event = new_event.tap(&:save!)
    found = Planner::Event.find(event.id)
    found.update!(title: "Orthodontist")
    _(Planner::Event.find(event.id).title).must_equal "Orthodontist"
  end

  it "belongs to the user of the record, whoever asks" do
    _(new_event.tap(&:save!).then { Core::Entity.find(it.id).user_id }).must_equal users(:member).id
  end
end
