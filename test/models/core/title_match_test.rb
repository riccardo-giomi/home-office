require "test_helper"

describe Core::TitleMatch do
  let(:user) { users(:member) }
  let(:scope) { Planner::Todo.owned_by(user) }

  def titles(term) = Core::TitleMatch.apply(scope, term).pluck(:title)

  before do
    ["50% off", "snake_case", "back\\slash", "Plain thing"].each { |title| Planner::Todo.create!(user:, title:) }
  end

  it "leaves the scope alone for a blank term" do
    assert_equal scope.count, Core::TitleMatch.apply(scope, "  ").count
    assert_equal scope.count, Core::TitleMatch.apply(scope, nil).count
  end

  it "finds a part of the title, ignoring the case of plain letters" do
    assert_equal ["Plain thing"], titles("PLAIN")
  end

  it "takes percent, underscore and backslash literally" do
    assert_equal ["50% off"], titles("%")
    assert_equal ["snake_case"], titles("_")
    assert_equal ["back\\slash"], titles("\\")
    assert_equal ["50% off"], titles("0% o")
  end
end
