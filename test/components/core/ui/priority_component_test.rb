require "test_helper"

describe Core::UI::PriorityComponent do
  include ViewComponent::TestHelpers

  names = {low: "Low priority", normal: "Normal priority", high: "High priority", urgent: "Urgent priority"}.freeze

  define_method(:priority) { |level, **options| Core::UI::PriorityComponent.new(level:, label: names.fetch(level), **options) }

  %i[low high urgent].each do |level|
    it "is a pill named #{level} priority for a reader, with the name as a tooltip too" do
      render_inline(priority(level))
      assert_selector "span.badge[role=img][aria-label='#{names.fetch(level)}'][title='#{names.fetch(level)}']"
    end
  end

  it "has no visible text: the level is the number of bars, the color a second cue" do
    render_inline(priority(:high))
    assert_equal "", page.text.strip
    assert_selector "span.badge svg[aria-hidden=true] rect", count: 4
  end

  it "fills one more bar at each level" do
    filled = %i[low normal high urgent].map do |level|
      render_inline(priority(level, always: true)).css("rect").count { |bar| bar["opacity"].nil? }
    end
    _(filled).must_equal [1, 2, 3, 4]
  end

  it "has its own color for each of low, high and urgent" do
    classes = %i[low high urgent].map { |level| render_inline(priority(level)).css("span.badge").first["class"] }
    _(classes.uniq.size).must_equal 3
  end

  it "shows nothing for normal, which is the rule and not an exception" do
    render_inline(priority(:normal))
    assert_no_selector "span"
  end

  it "shows normal when asked to (the page of an item)" do
    render_inline(priority(:normal, always: true))
    assert_selector "span.badge[aria-label='Normal priority']"
  end

  it "can be smaller, for a grid card" do
    render_inline(priority(:urgent, compact: true))
    assert_selector "span.badge.badge-sm[aria-label='Urgent priority']"
  end

  it "refuses a level it does not know" do
    _ { render_inline(Core::UI::PriorityComponent.new(level: :banana, label: "x")) }.must_raise KeyError
  end
end
