require "test_helper"

describe Planner::CatchUp do
  it "defaults to lazy" do
    _(Planner::CatchUp.mode(nil)).must_equal :lazy
    _(Planner::CatchUp.mode("")).must_equal :lazy
  end

  it "takes lazy and off, in any case" do
    _(Planner::CatchUp.mode(" Off ")).must_equal :off
    _(Planner::CatchUp.mode("LAZY")).must_equal :lazy
  end

  it "refuses another word, naming the ones it takes" do
    error = _ { Planner::CatchUp.mode("weekly") }.must_raise(ArgumentError)
    _(error.message).must_match(/HOME_OFFICE_CATCH_UP.*lazy, off/)
  end

  it "is lazy on a request in lazy mode only" do
    {"lazy" => true, "off" => false}.each do |word, lazy|
      use_catch_up word
      _(Planner::CatchUp.lazy?).must_equal lazy
    end
  end
end
