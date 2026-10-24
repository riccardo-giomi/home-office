require "test_helper"

describe Planner::Todo do
  let(:user) { users(:admin) }
  let(:other) { users(:other_admin) }

  def create(title, owner: user, **attrs) = Planner::Todo.create!({user: owner, title:}.merge(attrs))

  def titles(owner = user) = Planner::Todo.owned_by(owner).in_order.map(&:title)

  def positions(owner = user) = Planner::Todo.owned_by(owner).in_order.map(&:position)

  before { Planner::Todo.delete_all }

  it "saves with a title only" do
    todo = Planner::Todo.new(user:, title: "Water the plants")
    _(todo.save).must_equal true
    _(todo.day).must_be_nil
    _(todo.timed?).must_equal false
  end

  it "is always done or not done" do
    _(create("Water", tracks_done: 0).tracks_done).must_equal 1
  end

  it "keeps a day and times it was given, as a converted event would" do
    todo = create("Dentist")
    todo.update_columns(day: Date.new(2026, 10, 7), starts_at: Time.utc(2026, 10, 7, 7), ends_at: Time.utc(2026, 10, 7, 8), time_zone: "Europe/Rome")
    _(todo.reload.valid?).must_equal true
    _(todo.day).must_equal Date.new(2026, 10, 7)
  end

  it "lists itself on the todos page" do
    _(Planner::Todo.listing_page).must_equal :todos
  end

  it "cannot be abandoned or cancelled" do
    todo = create("Water")
    _(todo.change_state("abandoned")).must_equal false
    _(todo.change_state("cancelled")).must_equal false
    _(todo.reload.state).must_equal "active"
    _(todo.state_changes).must_be_empty
  end

  describe "where a new todo goes" do
    it "puts low and normal ones at the bottom and high and urgent ones on top" do
      create("first")
      create("low", priority: :low)
      create("high", priority: :high)
      create("urgent", priority: :urgent)
      create("normal")
      _(titles).must_equal %w[urgent high first low normal]
      _(positions).must_equal [1, 2, 3, 4, 5]
    end

    it "does not move when its priority changes later" do
      create("a")
      b = create("b")
      create("c")
      b.update!(priority: :urgent)
      _(titles).must_equal %w[a b c]
    end

    it "counts from 1 for each user" do
      create("mine")
      create("theirs", owner: other)
      _([positions, positions(other)]).must_equal [[1], [1]]
    end

    it "does not share numbers with tasks" do
      create("todo")
      task = Planner::Task.create!(user:, title: "task", day: Date.new(2026, 10, 7))
      _(task.position).wont_be_nil
      _(positions).must_equal [1]
    end
  end

  describe "#move" do
    let(:a) { create("a") }
    let(:b) { create("b") }
    let(:c) { create("c") }
    let(:d) { create("d") }

    before { [a, b, c, d] }

    it "moves up and down by one place" do
      _(c.move(:up)).must_equal true
      _(titles).must_equal %w[a c b d]
      _(c.reload.move(:down)).must_equal true
      _(titles).must_equal %w[a b c d]
    end

    it "moves to the top and to the bottom" do
      c.move(:top)
      _(titles).must_equal %w[c a b d]
      c.reload.move(:bottom)
      _(titles).must_equal %w[a b d c]
    end

    it "does nothing, and says so, when it is already there" do
      _(a.move(:up)).must_equal false
      _(a.move(:top)).must_equal false
      _(d.move(:down)).must_equal false
      _(d.move(:bottom)).must_equal false
      _(titles).must_equal %w[a b c d]
    end

    it "goes right before or after another todo" do
      d.move(before: b)
      _(titles).must_equal %w[a d b c]
      a.reload.move(after: c)
      _(titles).must_equal %w[d b c a]
    end

    it "refuses a target that is itself, someone else's, or not a todo" do
      foreign = create("foreign", owner: other)
      event = planner_items(:dentist)
      [c, foreign, event, nil, "junk", :banana].each do |target|
        _(c.move(before: target)).must_equal false
        _(c.move(after: target)).must_equal false
      end
      _(c.move(:banana)).must_equal false
      _(titles).must_equal %w[a b c d]
      _(titles(other)).must_equal %w[foreign]
    end

    it "uses the order as it is now, not the one the record remembers" do
      stale = Planner::Todo.find(d.id)
      a.move(:bottom)
      b.reload.move(:bottom)
      _(titles).must_equal %w[c d a b]
      _(stale.move(:top)).must_equal true
      _(titles.first).must_equal "d"
      _(positions).must_equal [1, 2, 3, 4]
    end

    it "leaves other users' and other types' positions alone" do
      theirs = create("theirs", owner: other)
      task = Planner::Task.create!(user:, title: "task", day: Date.new(2026, 10, 7))
      task_position = task.position
      d.move(:top)
      _([theirs.reload.position, task.reload.position]).must_equal [1, task_position]
    end
  end

  it "closes the gap when one is deleted, and other types do not disturb it" do
    [create("a"), create("b"), create("c")]
    Planner::Todo.find_by(title: "a").destroy
    _(positions).must_equal [1, 2]
    planner_items(:dentist).destroy
    _(positions).must_equal [1, 2]
  end

  describe "with trashed todos" do
    it "moves over trashed neighbors and ignores them at the ends" do
      a, b, c = %w[a b c].map { |t| create(t) }
      b.trash
      c.move(:up)
      _(Planner::Todo.owned_by(user).kept.in_order.map(&:title)).must_equal %w[c a]
      _(c.reload.move(:top)).must_equal false
      _(a.reload.move(:bottom)).must_equal false
    end

    it "counts only kept todos in rank, and trashed ones leave the rank of the rest alone" do
      a, b, c = %w[a b c].map { |t| create(t) }
      b.trash
      _(c.rank).must_equal 2
      _(a.rank).must_equal 1
      _(c.position).must_be :>, 2
    end

    it "puts a new urgent todo above the kept ones even when the first slot is trashed" do
      a = create("a", priority: :low)
      a.trash
      create("b", priority: :low)
      urgent = create("u", priority: :urgent)
      _(Planner::Todo.owned_by(user).kept.in_order.map(&:title)).must_equal %w[u b]
      _(urgent.rank).must_equal 1
    end
  end
end
