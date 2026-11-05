require "test_helper"

describe Planner::ItemRef do
  let(:user) { users(:member) }
  let(:gym) do
    Planner::Series.create!(user:, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60)
  end
  let(:monday) { Date.new(2026, 10, 12) }

  def resolve(ref, as: user) = Planner::ItemRef.resolve(as, ref)

  describe ".resolve" do
    it "finds an item by its id" do
      todo = Planner::Todo.create!(user:, title: "Pay")
      _(resolve(todo.id.to_s)).must_equal todo
      _(resolve(todo.id)).must_equal todo
    end

    it "gives an unsaved occurrence for a series and a date the rule gives" do
      unsaved = resolve("s#{gym.id}@#{monday}")
      _(unsaved).must_be :new_record?
      _([unsaved.series_id, unsaved.occurrence_on, unsaved.title]).must_equal [gym.id, monday, "Gym"]
    end

    it "gives the row once the occurrence has been saved, with the same ref" do
      ref = "s#{gym.id}@#{monday}"
      row = gym.materialize(monday)
      _(resolve(ref)).must_equal row
      _(resolve(row.id.to_s)).must_equal row
    end

    it "gives nothing for a date the rule does not give or that is excluded" do
      gym.exclusions.create!(user_id: user.id, excluded_on: monday)
      _(resolve("s#{gym.id}@#{monday}")).must_be_nil
      _(resolve("s#{gym.id}@2026-10-13")).must_be_nil
    end

    it "gives nothing for a trashed item, a trashed occurrence or a trashed series" do
      todo = Planner::Todo.create!(user:, title: "Pay").tap(&:trash)
      _(resolve(todo.id.to_s)).must_be_nil
      gym.materialize(monday).trash
      _(resolve("s#{gym.id}@#{monday}")).must_be_nil
      gym.trash
      _(resolve("s#{gym.id}@2026-10-19")).must_be_nil
    end

    it "gives nothing for another user's item or series" do
      todo = Planner::Todo.create!(user:, title: "Pay")
      other = users(:other_admin)
      _(resolve(todo.id.to_s, as: other)).must_be_nil
      _(resolve("s#{gym.id}@#{monday}", as: other)).must_be_nil
    end

    it "gives nothing for text that is not a ref" do
      ["", " ", "abc", "s@2026-10-12", "s1@", "s1@2026-13-45", "1; DROP TABLE", "0", "-1", "s#{gym.id}@2026-10-12x", nil, [], {}].each do |text|
        assert_nil resolve(text), "resolved #{text.inspect}"
      end
    end
  end

  describe ".changing" do
    it "runs the change on the row that won when another request saved the occurrence first" do
      unsaved = resolve("s#{gym.id}@#{monday}")
      result = Planner::ItemRef.changing(unsaved) do |target|
        gym.materialize(monday) if target.new_record?
        target.update!(title: "Moved")
        target
      end
      _(result).must_be :persisted?
      _(result.title).must_equal "Moved"
      _(Planner::Event.where(series_id: gym.id, occurrence_on: monday).pluck(:title)).must_equal ["Moved"]
    end
  end
end
