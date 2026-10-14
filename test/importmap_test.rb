require "test_helper"

describe "importmap" do
  it "pins only local files" do
    remote = File.readlines(Rails.root.join("config/importmap.rb")).grep(/https?:\/\//)
    _(remote).must_be_empty
  end
end
