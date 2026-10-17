require "test_helper"

describe Core::ColumnPacking do
  def pack(*spans)
    span = Struct.new(:name, :from, :to)
    Core::ColumnPacking.call(spans.map { |name, from, to| span.new(name, from, to) })
  end

  def layout(result) = result.placements.map { |p| [p.entry.name, p.column, p.columns] }

  it "shares columns inside a cluster and reuses freed ones" do
    result = pack([:a, 540, 600], [:b, 570, 630], [:c, 600, 660], [:d, 700, 720], [:e, 540, 545])
    # e is drawn 30 minutes (540-570), so b (570) can reuse its column
    _(layout(result)).must_equal [[:a, 0, 2], [:e, 1, 2], [:b, 1, 2], [:c, 0, 2], [:d, 0, 1]]
  end

  it "puts three simultaneous entries side by side and the next one alone" do
    result = pack([:a, 60, 120], [:b, 60, 120], [:c, 60, 120], [:z, 120, 180])
    _(layout(result)).must_equal [[:a, 0, 3], [:b, 1, 3], [:c, 2, 3], [:z, 0, 1]]
  end

  it "does not let entries that only touch share a cluster" do
    result = pack([:a, 540, 600], [:b, 600, 660])
    _(layout(result)).must_equal [[:a, 0, 1], [:b, 0, 1]]
  end

  it "draws an entry shorter than 30 minutes 30 minutes tall and packs against that" do
    result = pack([:short, 600, 605], [:next, 620, 660])
    _(result.placements.first.to).must_equal 630
    _(layout(result)).must_equal [[:short, 0, 2], [:next, 1, 2]]
  end

  it "starts the longer entry first when two start together" do
    result = pack([:short, 60, 90], [:long, 60, 180])
    _(layout(result).first).must_equal [:long, 0, 2]
  end

  it "keeps input order for identical entries" do
    result = pack([:x, 60, 120], [:y, 60, 120])
    _(layout(result)).must_equal [[:x, 0, 2], [:y, 1, 2]]
  end

  it "reports entries that would need a fifth column as overflow" do
    result = pack(*(1..5).map { |i| [:"e#{i}", 60, 120] })
    _(result.placements.size).must_equal 4
    _(result.overflow.map(&:name)).must_equal [:e5]
    _(result.placements.map(&:columns).uniq).must_equal [4]
  end

  it "handles no entries" do
    result = pack
    _([result.placements, result.overflow]).must_equal [[], []]
  end
end
