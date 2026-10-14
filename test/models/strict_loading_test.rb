require "test_helper"

describe "strict loading" do
  it "is on by default in test, for every lazy load" do
    _(ActiveRecord::Base.strict_loading_by_default).must_equal true
    _(ActiveRecord::Base.strict_loading_mode).must_equal :all
  end
end
