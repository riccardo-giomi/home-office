require "test_helper"

describe "public/robots.txt" do
  it "asks every crawler to stay away from the whole application" do
    text = Rails.root.join("public/robots.txt").read
    _(text).must_match(/^User-agent: \*$/)
    _(text).must_match(/^Disallow: \/$/)
  end
end
