require "test_helper"

describe Core::LinkIndex do
  let(:admin) { users(:admin) }
  let(:dentist) { core_entities(:dentist).id }

  def index(*labels) = Core::LinkIndex.new(labels.map { |label| core_entities(label).id })

  it "gives the other end of each link, from either side, with its typed record" do
    ends = index(:dentist).ends_of(dentist)
    others = ends.map { |link_end| [link_end.entity.id, link_end.record.class] }
    _(others).must_include [core_entities(:pay_rent_task).id, Planner::Task]
    _(others).must_include [core_entities(:water_plants_todo).id, Planner::Todo]
    _(ends.map { |link_end| link_end.link.id }).wont_include core_links(:pay_rent_and_buy_stamps).id
  end

  it "answers for every id it was asked about" do
    index = index(:pay_rent_task, :buy_stamps_task)
    _(index.ends_of(core_entities(:buy_stamps_task).id).map { |e| e.record.title }).must_equal ["Pay the rent"]
    _(index.ends_of(core_entities(:pay_rent_task).id).map { |e| e.record.title }).must_equal ["Dentist", "Buy stamps"]
  end

  it "puts kept ends first and trashed ends last, and counts only the kept" do
    ends = index(:dentist).ends_of(dentist)
    _(ends.last).must_be :trashed?
    _(ends.last.record.title).must_equal planner_items(:trashed_task).title
    _(ends[0..-2]).wont_include(ends.last)
    _(ends[0..-2].none?(&:trashed?)).must_equal true
    _(index(:dentist).kept_count(dentist)).must_equal ends.size - 1
  end

  it "knows the words a row needs" do
    link_end = index(:dentist).ends_of(dentist).find { |e| e.record.is_a?(Planner::Task) && !e.trashed? }
    _(link_end.kind_key).must_equal "task"
    _(link_end.label).must_equal "Pay the rent"
    _(link_end.status).must_be_nil
  end

  it "is empty for a record with no links, and for an id it was not asked about" do
    index = index(:holiday)
    _(index.ends_of(core_entities(:holiday).id)).must_equal []
    _(index.ends_of(dentist)).must_equal []
    _(index.kept_count(core_entities(:holiday).id)).must_equal 0
  end

  it "never shows another user's links" do
    mine = index(:other_users_event).ends_of(core_entities(:other_users_event).id)
    _(mine.map { |e| e.link.user_id }.uniq).must_equal [users(:other_admin).id]
    _(index(:dentist).ends_of(dentist).map { |e| e.link.user_id }.uniq).must_equal [admin.id]
  end

  it "asks three questions, however many links there are" do
    own = dentist
    items = Planner::Item.where(user_id: admin.id).to_a
    items.each_cons(2) { |a, b| Core::Link.connect(admin, a.id, b.id) }
    few = selects { Core::LinkIndex.new([own]).then { |i| i.ends_of(own).each { |e| e.record.title && e.trashed? } } }
    many = selects { Core::LinkIndex.new(items.map(&:id)).then { |i| items.each { |item| i.ends_of(item.id).each { |e| e.record.title && e.trashed? } } } }
    _(few.size).must_equal 3
    _(many.size).must_equal 3
  end
end
