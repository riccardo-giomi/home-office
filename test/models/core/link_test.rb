require "test_helper"

describe Core::Link do
  let(:admin) { users(:admin) }
  let(:ids) { ->(*labels) { labels.map { |label| core_entities(label).id } } }

  describe ".connect" do
    it "stores the lower id first whichever way round the ends come" do
      one, two = ids.call(:holiday, :rent_paid)
      link = Core::Link.connect(admin, [one, two].max, [one, two].min)
      _(link).must_be :persisted?
      _([link.first_entity_id, link.second_entity_id]).must_equal [one, two].sort
    end

    it "returns the link that exists, and says it did not make it" do
      first = Core::Link.connect(admin, *ids.call(:holiday, :rent_paid))
      assert_no_difference "Core::Link.count" do
        again = Core::Link.connect(admin, *ids.call(:rent_paid, :holiday))
        _(again.id).must_equal first.id
        _(again.previously_new_record?).must_equal false
      end
      _(first.previously_new_record?).must_equal true
    end

    it "links two of the same kind" do
      _(Core::Link.connect(admin, *ids.call(:holiday, :rent_paid))).must_be :persisted?
    end

    it "refuses a link to itself" do
      link = Core::Link.connect(admin, core_entities(:holiday).id, core_entities(:holiday).id)
      _(link).wont_be :persisted?
      _(link.errors.full_messages).must_equal ["You cannot link a record to itself."]
    end

    it "refuses another user's entity" do
      link = Core::Link.connect(admin, *ids.call(:holiday, :other_users_event))
      _(link).wont_be :persisted?
      _(link.errors[:base]).wont_be :empty?
    end

    it "refuses a trashed entity" do
      link = Core::Link.connect(admin, *ids.call(:holiday, :trashed_event))
      _(link).wont_be :persisted?
    end

    it "refuses an entity that does not exist, without raising" do
      link = Core::Link.connect(admin, core_entities(:holiday).id, 999_999)
      _(link).wont_be :persisted?
    end
  end

  describe "#reconnect" do
    let(:link) { core_links(:dentist_and_pay_rent) }
    let(:dentist) { core_entities(:dentist).id }

    it "replaces the end opposite the given one and keeps the given one" do
      same = link.reconnect(dentist, core_entities(:holiday).id)
      _(same.id).must_equal link.id
      _([same.first_entity_id, same.second_entity_id].sort).must_equal [dentist, core_entities(:holiday).id].sort
      _(same.reload.other_id(dentist)).must_equal core_entities(:holiday).id
    end

    it "hands back the link that already has the new pair and deletes nothing" do
      existing = core_links(:dentist_and_water_plants)
      assert_no_difference "Core::Link.count" do
        _(link.reconnect(dentist, core_entities(:water_plants_todo).id).id).must_equal existing.id
      end
      _(link.reload.other_id(dentist)).must_equal core_entities(:pay_rent_task).id
    end

    it "refuses a new end that is not available" do
      result = link.reconnect(dentist, core_entities(:other_users_event).id)
      _(result.errors[:base]).wont_be :empty?
      _(Core::Link.find(link.id).other_id(dentist)).must_equal core_entities(:pay_rent_task).id
    end
  end

  it "finds the links of an entity from either side" do
    found = Core::Link.involving(core_entities(:pay_rent_task).id).pluck(:id)
    _(found).must_include core_links(:dentist_and_pay_rent).id
    _(found).must_include core_links(:pay_rent_and_buy_stamps).id
    _(found).wont_include core_links(:other_users_pair).id
  end
end
