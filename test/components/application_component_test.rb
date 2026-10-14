require "test_helper"

describe ApplicationComponent do
  it "is the base of every component" do
    _(ApplicationComponent.superclass).must_equal ViewComponent::Base
  end
end
