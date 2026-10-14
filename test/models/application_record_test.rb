require "test_helper"

describe ApplicationRecord do
  it "is an abstract class" do
    _(ApplicationRecord).must_be :abstract_class?
  end
end
